#Create Namespace for app
write-host "creating namespace" -ForegroundColor Green
kubectl create namespace mysql

#Add Helm Chart for Bitnami
write-host "Adding Helm Repo" - -ForegroundColor Green
helm repo add bitnami https://charts.bitnami.com/bitnami

#install mysql
#create test my_sql application call "my-production-app"
write-host "Installing mysql" -ForegroundColor Green

helm install mysql bitnami/mysql --namespace=mysql --set primary.persistence.size=1Gi, volumePermissions.enabled=true
start-sleep 300

#Get password and decode it
$password = kubectl get secret --namespace mysql mysql -o jsonpath="{.data.mysql-root-password}"
$MYSQL_ROOT_PASSWORD = ([Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($password))) 

#Exec into container and create a DB called K10Demo
kubectl exec -it --namespace=mysql $(kubectl --namespace=mysql get pods -o jsonpath='{.items[0].metadata.name}') `
    -- mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE k10demo"

#Show Database exists.
kubectl exec -it --namespace=mysql $(kubectl --namespace=mysql get pods -o jsonpath='{.items[0].metadata.name}') `
    -- mysql -u root --password=$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES LIKE 'k10demo'"
