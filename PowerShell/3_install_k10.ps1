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
Start-Sleep 480

write-host "Setting default storage class" -ForegroundColor Green
#Annotate the CSI Hostpath VolumeSnapshotClass for use with K10
kubectl annotate volumesnapshotclass csi-hostpath-snapclass k10.kasten.io/is-snapshot-class=true

#change default storage class
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
