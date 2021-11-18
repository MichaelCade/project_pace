#!/bin/bash
echo "$(tput setaf 4)Create new cluster"
minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2 

echo "$(tput setaf 4)update helm repos if already present"
helm repo update

echo "$(tput setaf 4)Deploy Kasten K10"

helm repo add kasten https://charts.kasten.io/

kubectl create namespace kasten-io
helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true 

echo "$(tput setaf 4)Annotate Volumesnapshotclass"

kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true

echo "$(tput setaf 4)Change default storageclass"

kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "$(tput setaf 4)Deploy MySQL"

APP_NAME=my-production-app
kubectl create ns ${APP_NAME}
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mysql-store bitnami/mysql --set primary.persistence.size=1Gi,volumePermissions.enabled=true --namespace=${APP_NAME}
kubectl get pods -n ${APP_NAME}

echo "$(tput setaf 4)MySQL root password"

MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace ${APP_NAME} mysql-store -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
MYSQL_HOST=mysql-store.${APP_NAME}.svc.cluster.local
MYSQL_EXEC="mysql -h ${MYSQL_HOST} -u root --password=${MYSQL_ROOT_PASSWORD} -DmyImportantData -t"
echo MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

echo "$(tput setaf 4)Deploy PostgreSQL"
kubectl create ns postgres-test
helm install my-release --set primary.persistence.size=1Gi,volumePermissions.enabled=true --namespace postgres-test bitnami/postgresql
kubectl get pods -n postgres-test

echo "$(tput setaf 4)Deploy MongoDB"
kubectl create ns mongo-test
helm install my-release bitnami/mongodb --set architecture="replicaset",primary.persistence.size=1Gi,volumePermissions.enabled=true --namespace mongo-test

echo "$(tput setaf 4)Data Services deployment started" 
kubectl get pods -n my-production-app
kubectl get pods -n postgres-test
kubectl get pods -n mongo-test

echo "$(tput setaf 4)Waiting 5 mins for pod to come up"
sleep 5m
kubectl get pods -n my-production-app
kubectl get pods -n postgres-test
kubectl get pods -n mongo-test

echo "$(tput setaf 4)Display K10 Token Authentication" 
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "$(tput setaf 3)Token value: "
echo "$(tput setaf 3)$TOKEN"

echo "$(tput setaf 4)to access your Kasten K10 dashboard open a new terminal and run" 
echo "$(tput setaf 3)kubectl --namespace kasten-io port-forward service/gateway 8080:8000"
echo "$(tput setaf 4)Environment Complete"
