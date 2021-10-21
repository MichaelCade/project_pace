# Project Pace

- [Project Pace](#project-pace)
  - [Deploying a Kubernetes cluster on your local machine](#deploying-a-kubernetes-cluster-on-your-local-machine)
    - [Pre-reqs](#pre-reqs)
      - [Pre-reqs on Windows](#pre-reqs-on-windows)
    - [Minikube](#minikube)
      - [Minicube on Windows with VMware Workstation](#minicube-on-windows-with-vmware-workstation)
  - [Kasten K10](#kasten-k10)
  - [MySQL](#mysql)
  - [Step 1 - Deploy your mysql app for the first time](#step-1---deploy-your-mysql-app-for-the-first-time)
  - [Step 2 - Add Data Source](#step-2---add-data-source)
  - [Step 2a - Delete existing MySQL CLIENT](#step-2a---delete-existing-mysql-client)
  - [Step 2b - Add Data to MySQL](#step-2b---add-data-to-mysql)
  - [Create and Perform a backup of your data service](#create-and-perform-a-backup-of-your-data-service)
  - [Application Transformation](#application-transformation)
  - [Delete cluster](#delete-cluster)
  - [(NOT COMPLETE) Minio](#not-complete-minio)

## Deploying a Kubernetes cluster on your local machine 

This walkthrough enables you to deploy a Kubernetes cluster on your local workstation along with a Data Service (MySQL) and Kasten K10 to focus on Data Management of your Data Services. 

We will also optionally deploy a minio cluster which can act as an export repository for your backups, this is not seen as best practice in anyway but this walkthrough is good for hands on experience and learning. 

### Pre-reqs

- minikube - https://minikube.sigs.k8s.io/docs/start/ 
- helm - https://helm.sh/docs/intro/install/
- kubectl - https://kubernetes.io/docs/tasks/tools/ 

Container or virtual machine manager, such as: Docker, Hyperkit, Hyper-V, KVM, Parallels, Podman, VirtualBox, or VMware

I would also suggest that we need bash which means the advice for Windows users is install Git bash but for best experience use WSL 

For the above pre-reqs I use Arkade (https://github.com/alexellis/arkade) 

```
arkade get minikube helm kubectl
```

#### Pre-reqs on Windows

```
choco install minikube
```

```
choco install kubernetes-helm
```

```
choco install kubernetes-cli
```


### Minikube 
The first time you run the command below you will have to wait for the images to be downloaded locally to your machine, if you remove the container-runtime then the default will use docker. You can also add --driver=virtualbox if you want to use local virtualisation on your system. 

for reference on my ubuntu laptop this process took 6m 52s to deploy the minikube cluster

```
minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2 
```

I am also adding this as an option if you are using virtualbox this will command will create in virtualbox 

```
 minikube start --driver=virtualbox --addons volumesnapshots,csi-hostpath-driver,metallb --nodes 2 -p cade-demo container-runtime=containerd --kubernetes-version=1.21.2 --apiserver-port=6443
```
#### Minicube on Windows with VMware Workstation 

```
$Env:Path += ";C:\Program Files (x86)\VMware\VMware Workstation"
minikube start --driver vmware --addons volumesnapshots,csi-hostpath-driver
```

![Minicube on Windows with VMware Workstation](media\minicube_windows_vmware.jpg)

## Kasten K10 

Add the Kasten Helm repository

``` 
helm repo add kasten https://charts.kasten.io/
```
Create the namespace and deploy K10, note that this will take around 5 mins 

```
kubectl create namespace kasten-io
helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true
```
port forward to access the K10 dashboard, open a new terminal

```
kubectl --namespace kasten-io port-forward service/gateway 8080:8000
```

To authenticate with the dashboard we now need the token which we can get with the following commands. The first command will show us all secrets in the Kasten namespace, we need the k10-k10-token-XYZ12, copy the token into your web browser 

```
kubectl get secrets -n kasten-io
kubectl describe secret k10-k10-token-XYZ12 -n kasten-io
```
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

## MySQL
## Step 1 - Deploy your mysql app for the first time 

Deploying mysql via helm:

```
APP_NAME=my-production-app
kubectl create ns ${APP_NAME}
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mysql-store bitnami/mysql --set primary.persistence.size=1Gi,volumePermissions.enabled=true --namespace=${APP_NAME}
kubectl get pods -n ${APP_NAME} -w
```
## Step 2 - Add Data Source
Populate the mysql database with initial data, run the following:

```
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace ${APP_NAME} mysql-store -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
MYSQL_HOST=mysql-store.${APP_NAME}.svc.cluster.local
MYSQL_EXEC="mysql -h ${MYSQL_HOST} -u root --password=${MYSQL_ROOT_PASSWORD} -DmyImportantData -t"
echo MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

## Step 2a - Delete existing MySQL CLIENT 
if present and connect MySQL CLIENT

```
APP_NAME=my-production-app
kubectl delete pod -n ${APP_NAME} mysql-client
kubectl run mysql-client --rm --env APP_NS=${APP_NAME} --env MYSQL_EXEC="${MYSQL_EXEC}" --env MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} --env MYSQL_HOST=${MYSQL_HOST} --namespace ${APP_NAME} --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.23-debian-10-r57 --command -- bash
```

## Step 2b - Add Data to MySQL

```
echo "create database myImportantData;" | mysql -h ${MYSQL_HOST} -u root --password=${MYSQL_ROOT_PASSWORD}
MYSQL_EXEC="mysql -h ${MYSQL_HOST} -u root --password=${MYSQL_ROOT_PASSWORD} -DmyImportantData -t"
echo "drop table Accounts" | ${MYSQL_EXEC}
echo "create table if not exists Accounts(name text, balance integer); insert into Accounts values('nick', 0);" |  ${MYSQL_EXEC}
echo "insert into Accounts values('albert', 112);" | ${MYSQL_EXEC}
echo "insert into Accounts values('alfred', 358);" | ${MYSQL_EXEC}
echo "insert into Accounts values('beatrice', 1321);" | ${MYSQL_EXEC}
echo "insert into Accounts values('bartholomew', 34);" | ${MYSQL_EXEC}
echo "insert into Accounts values('edward', 5589);" | ${MYSQL_EXEC}
echo "insert into Accounts values('edwin', 144);" | ${MYSQL_EXEC}
echo "insert into Accounts values('edwina', 233);" | ${MYSQL_EXEC}
echo "insert into Accounts values('rastapopoulos', 377);" | ${MYSQL_EXEC}
echo "select * from Accounts;" |  ${MYSQL_EXEC}
exit
echo MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

## Create and Perform a backup of your data service 
in the K10 dashboard walkthrough and create yourself a policy to protect your mySQL data 

## Application Transformation 
if we check our storageclass options within our cluster with the following command, you will see that we have two we have a CSI and standard. 

```
kubectl get storageclass
``` 

Lets restore a clone of our data into a new namespace on a different storageclass by using transformations. notice below we are connecting to clone vs my-production-app 

```
APP_NAME=clone
kubectl delete pod -n ${APP_NAME} mysql-client
kubectl run mysql-client --rm --env APP_NS=${APP_NAME} --env MYSQL_EXEC="${MYSQL_EXEC}" --env MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} --env MYSQL_HOST=${MYSQL_HOST} --namespace ${APP_NAME} --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.23-debian-10-r57 --command -- bash
echo "select * from Accounts;" |  ${MYSQL_EXEC}
exit 
```

## Delete cluster 
When you are finished with the demo you can simply delete the cluster using the following command note if you have changed the name in the above steps then you will need to also update things here. 

```
minikube delete -p mc-demo
```



## (NOT COMPLETE) Minio  
In this optional section we will go against best practices and deploy our object storage export location for our K10 backups 


```
kubectl create namespace minio
helm repo add minio https://helm.min.io/
helm install --namespace minio --generate-name minio/minio
```
