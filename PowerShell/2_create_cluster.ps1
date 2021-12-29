#build cluster in minikube
write-host "Building Minikube Cluster" -ForegroundColor Green
minikube start `
    --memory 8192 `
    --cpus 4 `
    --disk-size 40GB `
    --driver=vmware `
    --addons volumesnapshots, csi-hostpath-driver `
    --apiserver-port=6443 `
    --container-runtime=containerd `
    --kubernetes-version=1.21.2