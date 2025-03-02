# PowerShell script to deploy n8n on Azure Kubernetes Service

param (
    [string]$ResourceGroup = "n8n-aks-rg",
    [string]$Location = "eastus",
    [string]$ClusterName = "n8n-aks-cluster",
    [int]$NodeCount = 2,
    [string]$VmSize = "Standard_DS2_v2"
)

# Create resource group
Write-Host "Creating resource group $ResourceGroup in $Location..."
az group create --name $ResourceGroup --location $Location

# Create AKS cluster
Write-Host "Creating AKS cluster $ClusterName..."
az aks create `
  --resource-group $ResourceGroup `
  --name $ClusterName `
  --node-count $NodeCount `
  --node-vm-size $VmSize `
  --enable-addons monitoring `
  --generate-ssh-keys

# Get credentials for kubectl
Write-Host "Getting credentials for kubectl..."
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

# Create n8n namespace
Write-Host "Creating n8n namespace..."
kubectl create namespace n8n

# Generate secrets
Write-Host "Generating secrets..."
& "$PSScriptRoot\generate-secrets.ps1"

# Apply Kubernetes configurations
Write-Host "Applying Kubernetes configurations..."
$KubernetesFiles = @(
    # Persistent Volume Claims
    "$PSScriptRoot\..\k8s\postgres-pvc.yaml",
    "$PSScriptRoot\..\k8s\redis-pvc.yaml",
    
    # Secrets
    "$PSScriptRoot\..\k8s\generated\secrets.yaml",
    
    # Database
    "$PSScriptRoot\..\k8s\postgres-deployment.yaml",
    "$PSScriptRoot\..\k8s\postgres-service.yaml",
    
    # Redis for queue mode
    "$PSScriptRoot\..\k8s\redis-deployment.yaml",
    "$PSScriptRoot\..\k8s\redis-service.yaml",
    
    # n8n main instance and worker
    "$PSScriptRoot\..\k8s\n8n-deployment.yaml",
    "$PSScriptRoot\..\k8s\n8n-service.yaml",
    "$PSScriptRoot\..\k8s\n8n-worker-deployment.yaml",
    
    # Autoscaling
    "$PSScriptRoot\..\k8s\n8n-autoscaler.yaml"
)

foreach ($File in $KubernetesFiles) {
    if (Test-Path $File) {
        Write-Host "Applying $File..."
        kubectl apply -f $File
    } else {
        Write-Host "Warning: File $File not found. Skipping."
    }
}

# Wait for deployments to be ready
Write-Host "Waiting for deployments to be ready..."
kubectl rollout status deployment/postgres -n n8n
kubectl rollout status deployment/redis -n n8n
kubectl rollout status deployment/n8n -n n8n
kubectl rollout status deployment/n8n-worker -n n8n

# Get n8n service external IP
Write-Host "Getting n8n service external IP..."
kubectl get service n8n -n n8n

Write-Host "Deployment complete. Use the EXTERNAL-IP above to access n8n."
Write-Host "Note: It might take a few minutes for the external IP to be assigned and for n8n to be fully ready."
Write-Host "Important: Replace 'YOUR_DOMAIN_OR_IP' in n8n-deployment.yaml with the actual external IP or domain name."
