#!/bin/bash

# Helm repository configuration
add_helm_repos() {
  echo "Adding Helm repositories..."
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
  helm repo update
  echo "Helm repositories added and updated."
}

# Deploy PostgreSQL
deploy_postgres() {
  echo "Deploying PostgreSQL..."
  kubectl create namespace postgres || true

  # Deploy PostgreSQL
  helm upgrade --install my-postgresql bitnami/postgresql \
    --namespace postgres \
    --set auth.postgresPassword=myPassword \
    --set auth.username=myUser \
    --set auth.database=myDatabase

  echo "PostgreSQL deployment complete."

  # Extract and print PostgreSQL credentials
  postgres_password=$(kubectl get secret --namespace postgres my-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)
  postgres_user=$(kubectl get secret --namespace postgres my-postgresql -o jsonpath="{.data.postgresql-username}" | base64 --decode)

  echo "PostgreSQL Credentials:"
  echo "  Username: $postgres_user"
  echo "  Password: $postgres_password"
  echo "  Host: my-postgresql.postgres.svc.cluster.local"
  echo "  Database: myDatabase"

  echo "To connect to PostgreSQL using kubectl:"
  echo "  kubectl run -n postgres -it --rm --image bitnami/postgresql:latest --env=\"PGPASSWORD=$postgres_password\" postgres-client -- psql --host my-postgresql.postgres.svc.cluster.local -U $postgres_user -d myDatabase"
}

# Deploy WordPress
deploy_wordpress() {
  echo "Deploying WordPress..."
  kubectl create namespace wordpress || true

  # Deploy WordPress (connecting to the PostgreSQL database)
  helm upgrade --install my-wordpress bitnami/wordpress \
    --namespace wordpress \
    --set mariadb.enabled=false \
    --set externalDatabase.host=my-postgresql.postgres.svc.cluster.local \
    --set externalDatabase.user=myUser \
    --set externalDatabase.password=myPassword \
    --set externalDatabase.database=myDatabase

  echo "WordPress deployment complete."
}

# Deploy Ghost
deploy_ghost() {
  echo "Deploying Ghost..."
  kubectl create namespace ghost || true

  helm upgrade --install my-ghost bitnami/ghost \
    --namespace ghost \
    --set mariadb.enabled=false \
    --set externalDatabase.host=my-postgresql.postgres.svc.cluster.local \
    --set externalDatabase.user=myUser \
    --set externalDatabase.password=myPassword \
    --set externalDatabase.database=myDatabase

  echo "Ghost deployment complete."
}

# Deploy JupyterHub
deploy_jupyterhub() {
  echo "Deploying JupyterHub..."
  kubectl create namespace jupyterhub || true

  helm upgrade --install jhub jupyterhub/jupyterhub \
    --namespace jupyterhub \
    --version=1.2.0 \
    --values https://raw.githubusercontent.com/jupyterhub/helm-chart/main/jupyterhub/values.yaml

  echo "JupyterHub deployment complete."
}

# Usage function
usage() {
  echo "Usage: $0 [-p] [-w] [-g] [-j]"
  echo "  -p, --postgres     Deploy PostgreSQL"
  echo "  -w, --wordpress    Deploy WordPress"
  echo "  -g, --ghost        Deploy Ghost"
  echo "  -j, --jupyterhub   Deploy JupyterHub"
  echo "If no options are provided, all apps will be deployed (except PostgreSQL)."
  exit 1
}

# Main script
deploy_postgres_flag=false
deploy_wordpress_flag=false
deploy_ghost_flag=false
deploy_jupyterhub_flag=false

# Parse command line arguments
if [ $# -eq 0 ]; then
  # No arguments, deploy all apps except PostgreSQL
  deploy_wordpress_flag=true
  deploy_ghost_flag=true
  deploy_jupyterhub_flag=true
else
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -p|--postgres) deploy_postgres_flag=true ;;
      -w|--wordpress) deploy_wordpress_flag=true ;;
      -g|--ghost) deploy_ghost_flag=true ;;
      -j|--jupyterhub) deploy_jupyterhub_flag=true ;;
      *) usage ;;
    esac
    shift
  done
fi

# Add and update Helm repos
add_helm_repos

# Deploy selected apps
if [ "$deploy_postgres_flag" = true ]; then
  deploy_postgres
fi

if [ "$deploy_wordpress_flag" = true ]; then
  deploy_wordpress
fi

if [ "$deploy_ghost_flag" = true ]; then
  deploy_ghost
fi

if [ "$deploy_jupyterhub_flag" = true ]; then
  deploy_jupyterhub
fi

echo "Deployment process complete."
