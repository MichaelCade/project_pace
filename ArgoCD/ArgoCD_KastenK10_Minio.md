## Backup is not a game! 

You have heard of continous integration and deployment but have you heard of **Continous Backup**?

In this session we are going to be using our own machines to - 

- deploy a Kubernetes cluster (Minikube) 
- deploy Kasten K10
- deploy ArgoCD 
- deploy Minio (Optional)
- configure ArgoCD to deploy our mission-critical application
- simulate some change to date service 
- recover with Kasten K10 

This assumes that you have the helm repositories on your system, I would generally run `helm repo update` at this stage so that my Kasten K10, ArgoCD and Minio apps are the lastet available. 

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

`minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p webinar-demo --kubernetes-version=1.21.2`

With the above we will be using Docker as our virtual machine manager. If you have not already you can grab Docker cross platform. 
[Get Docker](https://docs.docker.com/get-docker/)

### Deploy Kasten K10 

Add the Kasten Helm repository

`helm repo add kasten https://charts.kasten.io/`

We could use `arkade kasten install k10` here as well but for the purpose of the demo we will run through the following steps. [More Details](https://blog.kasten.io/kasten-k10-goes-to-the-arkade)

Create the namespace and deploy K10, note that this will take around 5 mins 

`helm install k10 kasten/k10 --namespace=kasten-io --create-namespace --set auth.tokenAuth.enabled=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true`

You can watch the pods come up by running the following command.

`kubectl get pods -n kasten-io -w`

You can also use the following to ensure all pods are up and Ready. 

`kubectl wait --for=condition=Ready pods --all -n kasten-io`

port forward to access the K10 dashboard, open a new terminal to run the below command

`kubectl --namespace kasten-io port-forward service/gateway 8080:8000`

The Kasten dashboard will be available at: `http://127.0.0.1:8080/k10/#/`

To authenticate with the dashboard we now need the token which we can get with the following commands. 

```
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "Token value: "
echo $TOKEN
```

## Install ArgoCD

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8181:443
```

Username is admin and password can be obtained with this command.

``` 
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## Kubernetes Storage changes

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
Patching the storage as above before installing Kasten K10 will result in the Prometheus pod not starting. 

## Adding the app to ArgoCD 


