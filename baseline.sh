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


echo "$(tput setaf 4)Display K10 Token Authentication" 
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "$(tput setaf 3)Token value: "
echo "$(tput setaf 3)$TOKEN"

echo "$(tput setaf 4)to access your Kasten K10 dashboard open a new terminal and run" 
echo "$(tput setaf 3)kubectl --namespace kasten-io port-forward service/gateway 8080:8000"
echo "$(tput setaf 4)Environment Complete"
