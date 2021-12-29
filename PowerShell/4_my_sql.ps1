#Check to see if script is running with Admin privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit;
}

#Create Namespace for app
write-host "creating namespace" -ForegroundColor Green
kubectl create namespace mysql

#Add Helm Chart for Bitnami
write-host "Adding Helm Repo" -ForegroundColor Green
helm repo add bitnami https://charts.bitnami.com/bitnami

#install mysql
#create test my_sql application call "my-production-app"
write-host "Installing mysql" -ForegroundColor Green

helm install mysql bitnami/mysql --namespace=mysql --set primary.persistence.size=1Gi,volumePermissions.enabled=true
Write-Host "Waiting for pod to start" -ForegroundColor Green
start-sleep 60

#Get password and decode it
$password = kubectl get secret --namespace mysql mysql -o jsonpath="{.data.mysql-root-password}"
$MYSQL_ROOT_PASSWORD = ([Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($password))) 

#Exec into container and create a DB called K10Demo
kubectl exec -it --namespace=mysql $(kubectl --namespace=mysql get pods -o jsonpath='{.items[0].metadata.name}') `
    -- mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE myImportantData"

kubectl exec -it --namespace=mysql $(kubectl --namespace=mysql get pods -o jsonpath='{.items[0].metadata.name}') `
    -- mysql -u root --password="$MYSQL_ROOT_PASSWORD" myImportantData -e `
    "CREATE TABLE Accounts(name text, balance integer); 
    insert into Accounts values('albert', 112);
    insert into Accounts values('alfred', 358);
    insert into Accounts values('beatrice', 1321);
    insert into Accounts values('bartholomew', 34);
    insert into Accounts values('edward', 5589);
    insert into Accounts values('edwin', 144);
    insert into Accounts values('edwina', 233);
    insert into Accounts values('rastapopoulos', 377);
    select * from Accounts;"
