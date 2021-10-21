## Deploying a Kubernetes cluster on your local machine 

This walkthrough enables you to deploy a Kubernetes cluster on your local workstation along with a Data Service (MySQL) and Kasten K10 to focus on Data Management of your Data Services. 

We will also optionally deploy a minio cluster which can act as an export repository for your backups, this is not seen as best practice in anyway but this walkthrough is good for hands on experience and learning. 

## Pre-reqs

- minikube - https://minikube.sigs.k8s.io/docs/start/ 
- helm - https://helm.sh/docs/intro/install/
- kubectl - https://kubernetes.io/docs/tasks/tools/ 

Container or virtual machine manager, such as: Docker, Hyperkit, Hyper-V, KVM, Parallels, Podman, VirtualBox, or VMware

I would also suggest that we need bash which means the advice for Windows users is install Git bash but for best experience use WSL 

For the above pre-reqs I use Arkade (https://github.com/alexellis/arkade) 

```
arkade get minikube helm kubectl
```

## Other Pre-reqs + notes

Whilst testing with Mac OS X and Docker, we noticed performance issues, when Kubernetes was enabled within Docker, with the new experimental feature "Use the new Virtualization framework". Disabling this experimental feature and restarting docker and minikube resulted in a more performant lab environment. 

## Minikube 
The first time you run the command below you will have to wait for the images to be downloaded locally to your machine, if you remove the container-runtime then the default will use docker. You can also add --driver=virtualbox if you want to use local virtualisation on your system. 

for reference on my ubuntu laptop this process took 6m 52s to deploy the minikube cluster

```
minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2 
```

I am also adding this as an option if you are using virtualbox this will command will create in virtualbox 

```
 minikube start --driver=virtualbox --addons volumesnapshots,csi-hostpath-driver,metallb --nodes 2 -p cade-demo container-runtime=containerd --kubernetes-version=1.21.2 --apiserver-port=6443
```

You can also set resource controls by using the following arguments with the above ```minikube start``` commands.

```
-cpus='2': Number of CPUs allocated to Kubernetes. Use "max" to use the
maximum number of CPUs.

--memory='': Amount of RAM to allocate to Kubernetes (format:
<number>[<unit>], where unit = b, k, m or g). Use "max" to use the maximum
amount of memory.
```

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
You can watch the pods come up by running the following command.
```
kubectl get pods -n kasten-io -w
```
port forward to access the K10 dashboard, open a new terminal to run the below command

```
kubectl --namespace kasten-io port-forward service/gateway 8080:8000
```

The Kasten dashboard will be available at: `http://127.0.0.1:8080/k10/#/`

To authenticate with the dashboard we now need the token which we can get with the following commands. The first command will show us all secrets in the Kasten namespace, we need the k10-k10-token-dnvrz (this will have a slightly different name in your environment), copy the token into your web browser 

```
kubectl get secrets -n kasten-io
kubectl describe secret k10-k10-token-dnvrz -n kasten-io
```
![image](https://user-images.githubusercontent.com/22192242/138279675-5f7e6867-299c-44d9-bd9f-6824628260d8.png)

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
helm install mysql-store bitnami/mysql --set primary.persistence.size=1Gi,volumePermissions.enabled=true,image.tag=5.7 --namespace=${APP_NAME}
kubectl get pods -n ${APP_NAME} -w
```

```
Note: we did find an issue running the latest version (8.x) of the Bitnami image with minikube
```
## Step 2 - Add Data Source
Populate the mysql database with initial data, run the following:

```
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace ${APP_NAME} mysql-store -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
MYSQL_HOST=mysql-store.${APP_NAME}.svc.cluster.local
MYSQL_EXEC="mysql -h ${MYSQL_HOST} -u root --password=${MYSQL_ROOT_PASSWORD} -DmyImportantData -t"
echo MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

## Step 2a - Create a MySQL CLIENT 
We will run another container image to act as our client

```
APP_NAME=my-production-app
kubectl run mysql-client --rm --env APP_NS=${APP_NAME} --env MYSQL_EXEC="${MYSQL_EXEC}" --env MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} --env MYSQL_HOST=${MYSQL_HOST} --namespace ${APP_NAME} --tty -i --restart='Never' --image  docker.io/bitnami/mysql:5.7 --command -- bash
```
```
Note: if you already have an existing mysql client pod running, delete with the command

kubectl delete pod -n ${APP_NAME} mysql-client
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
```

## Create and Perform a backup of your data service 
In the K10 dashboard walkthrough and create yourself a policy to protect your mySQL data.
1. Select 

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
