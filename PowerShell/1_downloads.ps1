#Internet Explorer's first launch configuration, This allows invoke-webrequest from running without any issues
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 2

#download Vmware workstation and install
write-host "Downloading VMware Workstation" -ForegroundColor Green
Invoke-WebRequest -OutFile "c:\users\$env:UserName\Downloads\VMware-workstation.exe" -Uri 'https://www.vmware.com/go/getworkstation-win' -UseBasicParsing
write-host "Installing VMware Workstation" -ForegroundColor Green
start-process "c:\users\$env:UserName\Downloads\VMware-workstation.exe" -ArgumentList '/s /v"/qn EULAS_AGREED=1 AUTOSOFTWAREUPDATE=1"'

$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\Program Files (x86)\VMware\VMware Workstation') {
 `
    [Environment]::SetEnvironmentVariable('Path', $('{0};C:\Program Files (x86)\VMware\VMware Workstation' -f $oldPath), [EnvironmentVariableTarget]::Machine) `

}

Start-Sleep 150
write-host "Please open VMware workstation now and accept the trial license" -ForegroundColor Green
Start-Sleep 30

#download the kubectl V1.21.2 and add to the system environment variables
new-item  -path "C:\kubectl" -ItemType Directory -Force
write-host "Downloading Kubectl" -ForegroundColor Green
Invoke-WebRequest -OutFile "c:\users\$env:UserName\Downloads\kubectl.exe" -Uri "https://dl.k8s.io/release/v1.21.2/bin/windows/amd64/kubectl.exe" -UseBasicParsing
Copy-Item "c:\users\$env:UserName\Downloads\kubectl.exe" -Destination "C:\kubectl"


$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\kubectl') {
 `
    [Environment]::SetEnvironmentVariable('Path', $('{0};C:\kubectl' -f $oldPath), [EnvironmentVariableTarget]::Machine) `

}
Start-Sleep 2
#download Helm and add to environment variables
new-item  -path "C:\helm" -ItemType Directory -Force
write-host "Downloading Helm" -ForegroundColor Green
Invoke-WebRequest -OutFile "C:\helm\helmzip.zip" -Uri 'https://get.helm.sh/helm-v3.7.1-windows-amd64.zip' -UseBasicParsing
Get-ChildItem 'C:\helm\' -Filter *.zip | Expand-Archive -DestinationPath 'C:\helm\' -Force
Copy-Item "C:\helm\windows-amd64\helm.exe" -Destination "C:\helm"
Remove-Item "C:\helm\helmzip.zip"
Remove-Item "C:\helm\windows-amd64" -Recurse

$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\helm') {
 `
    [Environment]::SetEnvironmentVariable('Path', $('{0};C:\helm' -f $oldPath), [EnvironmentVariableTarget]::Machine) `

}

Start-Sleep 2
#Download MiniKube, install and add minikube to environment variables
new-item  -path "C:\minikube" -ItemType Directory -Force
write-host "Downloading Minikube" -ForegroundColor Green
Invoke-WebRequest -OutFile "c:\users\$env:UserName\Downloads\minikube.exe" -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing
Copy-Item "c:\users\$env:UserName\Downloads\minikube.exe" -Destination "C:\minikube"

$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\minikube') {
 `
    [Environment]::SetEnvironmentVariable('Path', $('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::Machine) `

}

write-host "Please close this window and launch a new powershell window as administrator to start creating your cluster" -ForegroundColor Green