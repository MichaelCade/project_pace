## Zero to Hero: Kubernetes and Kasten K10
<p align="center">
<img src="/media/VUG.png" width=400 height=400>
</p>

This is for a session delivered at a global Veeam webinar to show how we can get Kasten K10 up and running on your local (x86 architecture) system using Minikube. 

[Link to Webinar](https://go.veeam.com/webinar-deploy-kubernetes-tips)

In this session we are going to deploy a minikube cluster to our local workstation, deploy some data services and then Kasten K10 to the same cluster. The performance of this will very much depend on your system. But the highlight here is that we can run K10 across multiple Kubernetes environments and with Minikube we do not need to pay for a cloud providers managed Kubernetes cluster to get hands-on. 

### Install Minikube 

- [Installing Minikube](https://minikube.sigs.k8s.io/docs/start/)

The minikube installation should also install kubectl or the Kubernetes CLI, you will need this, again available through most package managers cross platform (Chocolatey, apt etc.)

We will also need helm to deploy some of our data services. 

- [kubectl](https://kubernetes.io/docs/tasks/tools/) 
- [helm](https://helm.sh/docs/intro/install/) 

### Deploy Minikube cluster 

Once we have minikube available in our environment 

`minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p webinar-demo --kubernetes-version=1.26.0 `

With the above we will be using Docker as our virtual machine manager. If you have not already you can grab Docker cross platform. 
[Get Docker](https://docs.docker.com/get-docker/)

### Deploy Kasten K10 

Add the Kasten Helm repository

`helm repo add kasten https://charts.kasten.io/`

Update the repo

`helm repo update kasten`

Deploy K10, note that this will take around 5 mins 

`helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true --create-namespace`

You can watch the pods come up by running the following command.

`kubectl get pods -n kasten-io -w`

port forward to access the K10 dashboard, open a new `terminal` window to run the below command

`kubectl --namespace kasten-io port-forward service/gateway 8080:8000`

The Kasten dashboard will be available at: `http://127.0.0.1:8080/k10/#/`

To authenticate with the dashboard we now need the token which we can get with the following commands. Please bare in mind that this is not best practices and if you are running in a production environment then the K10 documentation should be followed accordingly. This is also applicable with Kubernetes clusters newer than v1.24 

```bash
kubectl --namespace kasten-io create token k10-k10 --duration=24h
```
For clusters older than v1.24 of Kubernetes then you can use this command to retrieve a token to authenticate. 

```bash
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "Token value: "
echo $TOKEN
```
## Storage Changes

Now that K10 is deployed and hopefully healthy we can now make some storage changes. 

Annotate the CSI Hostpath VolumeSnapshotClass for use with K10

```bash
kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true
```
we also need to change our default storageclass with the following 

```bash
kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```
Patching the storage as above before installing Kasten K10 will result in the Prometheus pod not starting. 

### Deploy Data Services (Pac-Man)

Setup the Pac-Man demo app using helm. This takes around 2 minutes.

```bash
helm repo add pacman https://shuguet.github.io/pacman/
helm repo update pacman

helm install pacman pacman/pacman -n pacman --create-namespace --wait
```

To expose and access this run the following port-forward in a new terminal

`kubectl port-forward svc/pacman 9191:80 -n pacman`

Open a browser and navigate to [http://localhost:9191/](http://localhost:9191/)

## Install Minio
```bash
helm repo add minio https://charts.min.io/
helm repo update minio

# Deploy minio with a pre-created "k10-bucket" bucket, and "minioaccess"/"miniosecret" creds
helm upgrade minio minio/minio --namespace minio --create-namespace  \
  --install \
  --set rootUser=rootuser,rootPassword=rootpass123 \
  --set persistence.size=5Gi \
  --set resources.requests.memory=2Gi \
  --set mode=standalone \
  --set 'buckets[0].name=k10-bucket,buckets[0].policy=none,buckets[0].purge=false' \
  --wait
```
Get the access key and secret key from installation

ACCESS_KEY=$(kubectl get secret minio -o jsonpath="{.data.accesskey}" -n minio | base64 --decode)
SECRET_KEY=$(kubectl get secret minio -o jsonpath="{.data.secretkey}" -n minio | base64 --decode)

echo $ACCESS_KEY
echo $SECRET_KEY 

Open a new terminal window to setup port forward to access the Minio Management page in your browser

````bash
kubectl --namespace minio port-forward svc/minio 9090:9000
````
Open your browser to http://127.0.0.1:9090 and login with the credentials from the above `echo` commands. 

## Configure S3 storage in Kasten
1. Click settings in the top right hand corner. Select locations and Create new location.
2. Provide a name, select "S3 Compatible", enter your Access Key and Secret Key you saved earlier from the `echo` commands.
3. Set the endpoint as "http://minio.minio.svc.cluster.local:9000" (this is the internal k8s dns name) and select to skip SSL verification.  
4. Provide the bucket name "k10-bucket" and click "Save Profile".

## Configure the Kasten Policy to export data to the S3 Storage
1. Edit your existing policy.
2. Enable the setting "Enable Backups via Snapshot Exports"
3. Select the S3 location profile you have just created, and set the schedule as necessary. Click the "Edit Policy" button. 
4. Manually run the policy and observe the run on the homescreen. After the backup run, you will see a new task called "Export".

Manually browse the Bucket from the Minio browser console, you will see your bucket contains a folder called "k10" and within that the protection data. 

![image](https://user-images.githubusercontent.com/22192242/138359395-b4175851-9da8-46d7-86b7-7cf3ee1e5fee.png)

![image](assets/minio-s3-kasten-k10-bucket.png)

### Dive into Kasten K10 

- Walkthrough K10 Dashboard 
- Add S3 location 
- Create a Policy protecting Pac-Man 
- Clock up a high score (Mission Critical Data)
- Delete Pac-Man Namespace
- Restore everything back to original location using K10 
- Clone and Transformation - Restore to other StorageClass available in cluster. 

## Clear up 

`minikube delete -p webinar-demo`
