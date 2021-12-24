#Create Namespace for app
write-host "creating namespace" - -ForegroundColor Green
$APP_NAME = "mysql"
kubectl create ns $APP_NAME

#Add Helm Chart for Bitnami
write-host "Adding Helm Repo" - -ForegroundColor Green
helm repo add bitnami https://charts.bitnami.com/bitnami

#install mysql
#create test my_sql application call "my-production-app"
write-host "Creating mysql app" - -ForegroundColor Green
write-host "Installing mysql" - -ForegroundColor Green
helm install mysql-store bitnami/mysql --set primary.persistence.size=1Gi,volumePermissions.enabled=true --namespace=$APP_NAME

#get my_sql root password and decode it
$MYSQL_ROOT_PASSWORD = kubectl get secret --namespace $APP_NAME mysql-store -o jsonpath="{.data.mysql-root-password}" 
$password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($MYSQL_ROOT_PASSWORD))

$MYSQL_HOST= "mysql-store.$APP_NAME.svc.cluster.local"
$MYSQL_EXEC ="mysql -h $MYSQL_HOST -u root --password=$password -DmyImportantData -t"

#We will run another container image to act as our client
kubectl run mysql-client `
--rm --env APP_NS="$APP_NAME" `
--env MYSQL_EXEC="$MYSQL_EXEC" `
--env MYSQL_ROOT_PASSWORD="$root" `
--env MYSQL_HOST="$MYSQL_HOST" `
--namespace "$APP_NAME" `
--tty -i --restart='Never' `
--image  docker.io/bitnami/mysql:latest --command -- bash 