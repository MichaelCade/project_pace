#Check to see if script is running with Admin privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit;
}

#build cluster in minikube
write-host "Building Minikube Cluster" -ForegroundColor Green
minikube start `
    --memory 8192 `
    --cpus 4 `
    --disk-size 40GB `
    --driver=vmware `
    --addons volumesnapshots,csi-hostpath-driver `
    --apiserver-port=6443 `
    --container-runtime=containerd `
    --kubernetes-version=1.21.2