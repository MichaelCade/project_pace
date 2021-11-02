#!/bin/bash
echo "Create cluster 1 "
minikube start --addons volumesnapshots,csi-hostpath-driver,metallb --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2 

echo "update helm repos if already present"
helm repo update

echo "Metallb config map with local IP address"
kubectl delete configmap config -n metallb-system
kubectl create -f metallbmcdemo.yaml

echo "Deploy Kasten K10"

helm repo add kasten https://charts.kasten.io/

kubectl create namespace kasten-io
helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set externalGateway.create=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true

echo "Annotate Volumesnapshotclass"

kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true

echo "Change default storageclass"

kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "Deploy MySQL"

APP_NAME=my-production-app
kubectl create ns ${APP_NAME}
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mysql-store bitnami/mysql --set primary.persistence.size=1Gi,volumePermissions.enabled=true --namespace=${APP_NAME}
kubectl get pods -n ${APP_NAME}

echo "Waiting 5 mins for pod to come up"
sleep 5m

kubectl get pods -n ${APP_NAME}

echo "MySQL root password"

MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace ${APP_NAME} mysql-store -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
MYSQL_HOST=mysql-store.${APP_NAME}.svc.cluster.local
MYSQL_EXEC="mysql -h ${MYSQL_HOST} -u root --password=${MYSQL_ROOT_PASSWORD} -DmyImportantData -t"
echo MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

echo "Install Minio"

helm repo add minio https://helm.min.io/
helm install --namespace minio-operator --create-namespace --generate-name minio/minio-operator

echo "Create cluster 2"
minikube start --addons volumesnapshots,csi-hostpath-driver,metallb --apiserver-port=6443 --container-runtime=containerd -p mc-demo2 --kubernetes-version=1.21.2 

echo "Metallb config map with local IP address"
kubectl delete configmap config -n metallb-system
kubectl create -f metallbmcdemo2.yaml


echo "Deploy Kasten K10"

helm repo add kasten https://charts.kasten.io/

kubectl create namespace kasten-io
helm install k10 kasten/k10 --namespace=kasten-io --set auth.tokenAuth.enabled=true --set externalGateway.create=true --set injectKanisterSidecar.enabled=true --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true

echo "Annotate Volumesnapshotclass"

kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true

echo "Change default storageclass"

kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'




echo "Environment Complete"