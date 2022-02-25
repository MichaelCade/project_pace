## Zero to Hero: Kubernetes and Kasten K10

[[media\VUG.png | width=200px]]

This is for a session delivered at a Veeam User Group to show how we can get Kasten K10 up and running on your local (x86 architecture) system using Minikube. 

In this session we are going to deploy a minikube cluster to our local workstation, deploy some data services and then Kasten K10 to the same cluster. The performance of this will very much depend on your system. But the highlight here is that we can run K10 across multiple Kubernetes environments and with Minikube we do not need to pay for a cloud providers managed Kubernetes cluster to get hands-on. 

### Install Minikube 

- [Installing Minikube](https://minikube.sigs.k8s.io/docs/start/)

Another option is using [Arkade](https://github.com/alexellis/arkade) with `arkade get minikube` 

With Arkade we also have the ability to install Kasten K10 and Kasten Open-Source projects. 

The minikube installation should also install kubectl or the Kubernetes CLI, you will need this, again available through most package managers cross platform (Chocolatey, apt etc.)

We will also need helm to deploy some of our data services. 

- [kubectl](https://kubernetes.io/docs/tasks/tools/) or `arkade get kubectl`
- [helm](https://helm.sh/docs/intro/install/) or `arkade get helm`

### Deploy Minikube cluster 

Once we have minikube available in our environment 

`minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p vug-demo --kubernetes-version=1.21.2`

With the above we will be using Docker as our virtual machine manager. If you have not already you can grab Docker cross platform. 
[Get Docker](https://docs.docker.com/get-docker/)

Annotate the CSI Hostpath VolumeSnapshotClass for use with K10

```
kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true
```
we also need to change our default storageclass with the following 

```
kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

### Deploy Kasten K10 

Add the Kasten Helm repository

`helm repo add kasten https://charts.kasten.io/`

We could use `arkade kasten install k10` here as well but for the purpose of the demo we will run through the following steps. [More Details](https://blog.kasten.io/kasten-k10-goes-to-the-arkade)

Create the namespace and deploy K10, note that this will take around 5 mins 

`kubectl create namespace kasten-io`

`helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true`

You can watch the pods come up by running the following command.

`kubectl get pods -n kasten-io -w`

port forward to access the K10 dashboard, open a new terminal to run the below command

`kubectl --namespace kasten-io port-forward service/gateway 8080:8000`

The Kasten dashboard will be available at: `http://127.0.0.1:8080/k10/#/`

To authenticate with the dashboard we now need the token which we can get with the following commands. 

```
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "Token value: "
echo $TOKENv
```

### Deploy Data Services (Pac-Man)

Make sure you are in the directory where this YAML config file is and run against your cluster. 

`kubectl create -f pacman-stateful-demo.yaml`

To expose and access this run the following port-forward in a new terminal

`kubectl port-forward svc/pacman 9090:80 -n pacman`
`kubectl port-forward deployment/pacman 9090:80 -n pacman`

Open a browser and navigate to [http://localhost:9090/](http://localhost:9090/)

### Dive into Kasten K10 

- Walkthrough K10 Dashboard 
- Add S3 location 
- Create a Policy protecting Pac-Man 
- Clock up a high score (Mission Critical Data)
- Delete Pac-Man Namespace
- Restore everything back to original location using K10 
- Clone and Transformation - Restore to other StorageClass available in cluster. 