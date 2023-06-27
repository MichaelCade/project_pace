# Welcome to Project Pace 



Project Pace is a project aimed to enable a fast and efficent way of getting hands on with Kasten K10 and data services within a local minikube kubernetes cluster. 

## Who is it for?

The aim of the project is to provide the ability to get hands on and demonstrate features, functionality and solutions to data management issues in the cloud-native space. I expect that there are three groups targeted: 

- Veeam & Kasten engineers wanting a fast demo environment for specific use cases and solutions. 
- Partner technologists wanting to get hands on with Kasten K10 and learn more without really having to understand Kubernetes in any real detail. 
- The hobbyist technologist looking to get hands on and learn.

## How can you help? 

The repository will continue to grow and add more and more demo scenarios to deploy, if you have an idea then please contribute. 

## The baseline deployment 

Each demo environment is going to always consist of at least 

- 1 minikube cluster with specific addons enabled. 
- Kasten K10 deployed (unless a lab focused on the deployment options)

This can be achieved by following the instructions below or you could use the [baseline bash script in the repository](baseline.sh) 

## minikube installation 

Initially we need to have the following in place on our systems, the instructions found should be viable across x86 architecture and across Windows, Linux and MacOS operating systems. 

- minikube - https://minikube.sigs.k8s.io/docs/start/ 
- helm - https://helm.sh/docs/intro/install/
- kubectl - https://kubernetes.io/docs/tasks/tools/ 

The first time you run the command below you will have to wait for the images to be downloaded locally to your machine, if you remove the container-runtime then the default will use docker. You can also add --driver=virtualbox if you want to use local virtualisation on your system. 

for reference on my ubuntu laptop this process took 6m 52s to deploy the minikube cluster

```
minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.26.0 
```


## Kasten K10 deployment 
Add the Kasten Helm repository

``` 
helm repo add kasten https://charts.kasten.io/
```
Create the namespace and deploy K10, note that this will take around 5 mins 

```
kubectl create namespace kasten-io
helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true
```
You can watch the pods come up by running the following command.
```
kubectl get pods -n kasten-io -w
```
port forward to access the K10 dashboard, open a new terminal to run the below command

```
kubectl --namespace kasten-io port-forward service/gateway 8080:8000
```

The Kasten dashboard will be available at: `http://127.0.0.1:8080/k10/#/`

To authenticate with the dashboard we now need the token which we can get with the following commands. Please bare in mind that this is not best practices and if you are running in a production environment then the K10 documentation should be followed accordingly. This is also applicable with Kubernetes clusters newer than v1.24 

```
kubectl --namespace kasten-io create token k10-k10 --duration=24h
```
For clusters older than v1.24 of Kubernetes then you can use this command to retrieve a token to authenticate. 

```
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "Token value: "
echo $TOKEN
```

## StorageClass Configuration 

Out of the box Kasten K10 should be installed on the standard storageclass within your cluster this ensures that all pods and services are available. If you run this change below beforehand and the CSI storage is used then there is an issue with Prometheus on the deployment. 

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

## What next? 

Now you have at least one minikube cluster up and running and available with Kasten K10 deployed we can choose from the following walkthroughs. 

- Initial Kubernetes deployment and configuration (Use pre-existing minikube commands with add-ons and version)
- Helm deployment walkthrough using Kasten K10 as the example
- Helm deployment walkthrough using Kanister as the example
- Kubestr demo session on finding out the availability of storage and usability within your Kubernetes cluster.
- Kasten K10 overview walkthrough - Initial configuration (location profiles) (S3 object lock) | K10 Upgrades |
- Kasten K10 + Data Services backup and restore walkthrough (we could do one for Postgres, MySQL, MongoDB etc.)
- Kasten K10 + Application consistency using blueprints
- Kanister + Application consistency backups and restore
- Kasten K10 multi-cluster walkthrough - deploy two minikube clusters, deploy k10 in both walks through the process of creating a cluster
- Kasten K10 Disaster Recovery walkthrough - this should cover both K10 catalogue DR but also app DR
- Kasten K10 Monitoring and Reporting walkthrough - We should also create a new dashboard and set up notifications to email and slack
- Kasten K10 - Integrating backup into your GitOps pipeline
- Kasten K10 - Integrating restore into your GitOps pipeline
- Kanister - Integrating app consistent backups into your GitOps pipeline
- Kasten K10 - Policy as Code (OPA)
- Kasten K10 - Policy as Code (Kyverno)
- Terraform - Kasten K10
- Ansible - Kasten K10
- ClickOps - Kasten K10 - UI-only walkthrough
- Kasten K10 + AWS RDS
- HashiCorp Vault + Kasten K10
- OIDC Demonstration with Okta and K10
- Is there anything we can do with alocal OpenShift cluster demonstration?
