#!/bin/bash
# Bash script to deploy n8n on Azure Kubernetes Service

# Default values
RESOURCE_GROUP="n8n-aks-rg"
LOCATION="eastus"
CLUSTER_NAME="n8n-aks-cluster"
NODE_COUNT=2
VM_SIZE="Standard_DS2_v2"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --resource-group|-g)
        RESOURCE_GROUP="$2"
        shift
        shift
        ;;
        --location|-l)
        LOCATION="$2"
        shift
        shift
        ;;
        --cluster-name|-c)
        CLUSTER_NAME="$2"
        shift
        shift
        ;;
        --node-count|-n)
        NODE_COUNT="$2"
        shift
        shift
        ;;
        --vm-size|-s)
        VM_SIZE="$2"
        shift
        shift
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Create resource group
echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster
echo "Creating AKS cluster $CLUSTER_NAME..."
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $VM_SIZE \
  --enable-addons monitoring \
  --generate-ssh-keys

# Get credentials for kubectl
echo "Getting credentials for kubectl..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Create n8n namespace
echo "Creating n8n namespace..."
kubectl create namespace n8n

# Generate secrets
echo "Generating secrets..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/generate-secrets.sh"

# Apply Kubernetes configurations
echo "Applying Kubernetes configurations..."
KUBERNETES_FILES=(
    # Persistent Volume Claims
    "$SCRIPT_DIR/../k8s/postgres-pvc.yaml"
    "$SCRIPT_DIR/../k8s/redis-pvc.yaml"
    
    # Secrets
    "$SCRIPT_DIR/../k8s/generated/secrets.yaml"
    
    # Database
    "$SCRIPT_DIR/../k8s/postgres-deployment.yaml"
    "$SCRIPT_DIR/../k8s/postgres-service.yaml"
    
    # Redis for queue mode
    "$SCRIPT_DIR/../k8s/redis-deployment.yaml"
    "$SCRIPT_DIR/../k8s/redis-service.yaml"
    
    # n8n main instance and worker
    "$SCRIPT_DIR/../k8s/n8n-deployment.yaml"
    "$SCRIPT_DIR/../k8s/n8n-service.yaml"
    "$SCRIPT_DIR/../k8s/n8n-worker-deployment.yaml"
    
    # Autoscaling
    "$SCRIPT_DIR/../k8s/n8n-autoscaler.yaml"
)

for FILE in "${KUBERNETES_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "Applying $FILE..."
        kubectl apply -f "$FILE"
    else
        echo "Warning: File $FILE not found. Skipping."
    fi
done

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/postgres -n n8n
kubectl rollout status deployment/redis -n n8n
kubectl rollout status deployment/n8n -n n8n
kubectl rollout status deployment/n8n-worker -n n8n

# Get n8n service external IP
echo "Getting n8n service external IP..."
kubectl get service n8n -n n8n

echo "Deployment complete. Use the EXTERNAL-IP above to access n8n."
echo "Note: It might take a few minutes for the external IP to be assigned and for n8n to be fully ready."
echo "Important: Replace 'YOUR_DOMAIN_OR_IP' in n8n-deployment.yaml with the actual external IP or domain name."
