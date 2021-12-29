#Check to see if script is running with Admin privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please relaunch Powershell as admin" -BackgroundColor Red
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit;
}

#Add helm repo
write-host "Add Kasten Helm Chart" -ForegroundColor Green
helm repo add kasten https://charts.kasten.io/

#install kasten
write-host "Installing Kasten" -ForegroundColor Green
kubectl create namespace kasten-io
helm install k10 kasten/k10 `
    --namespace=kasten-io `
    --set auth.tokenAuth.enabled=true `
    --set injectKanisterSidecar.enabled=true `
    --set-string injectKanisterSidecar.namespaceSelector.matchLabels.k10/injectKanisterSidecar=true `
    --set eula.accept=true `
    --set eula.company="Company" `
    --set eula.email="a@a.com"

#wait for pods to come up
##need to do better than just a sleep
Write-Host "Waiting for pods to be ready, This could take up to 5 minutes" -ForegroundColor Green
#Start-Sleep 300
$ready = kubectl get pod -n kasten-io --selector=component=catalog -o=jsonpath='{.items[*].status.phase}'
do {
    Write-Host "Waiting for pods to be ready" -ForegroundColor Green
    start-sleep 20
    $ready = kubectl get pod -n kasten-io --selector=component=catalog -o=jsonpath='{.items[*].status.phase}'
} while ($ready -notlike "Running")
Write-Host "Pods are ready, moving on" -ForegroundColor Green

#Annotate the CSI Hostpath VolumeSnapshotClass for use with K10
write-host "Setting default storage class" -ForegroundColor Green
kubectl annotate volumesnapshotclass csi-hostpath-snapclass k10.kasten.io/is-snapshot-class=true
kubectl patch storageclass csi-hostpath-sc -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'
kubectl patch storageclass standard -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"false\"}}}'

#Get K10 secret and extract login token
$secret = kubectl get secrets -n kasten-io | select-string -Pattern "k10-k10-token-\w*" | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }
$k10token = kubectl -n kasten-io -ojson get secret $secret | convertfrom-json | Select-Object data

#port forward Kasten Dashboard in a seperate powershell window to keep it open
Start-Job -ScriptBlock { kubectl --namespace kasten-io port-forward service/gateway 8080:8000 }

Write-Host "Please log into the Kasten Dashboard http://127.0.0.1:8080/k10/#/ using the token below `n" -ForegroundColor blue
Write-Host '#########################################################################'  -ForegroundColor Green
Write-Host ([Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($k10token.data.token))) -ForegroundColor Green
Write-Host '#########################################################################'  -ForegroundColor Green