#!/usr/bin/env pwsh
# Deploy n8n components to an existing AKS cluster
# This script assumes you have already created an AKS cluster and have kubectl configured to access it

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "n8n-aks-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "n8n-aks-cluster"
)

# Get AKS credentials
Write-Host "`nGetting AKS credentials..." -ForegroundColor Cyan
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

# Create namespace
Write-Host "`nCreating n8n namespace..." -ForegroundColor Cyan
kubectl create namespace n8n

# Generate secrets
Write-Host "`nGenerating secrets..." -ForegroundColor Cyan
& "$PSScriptRoot\generate-secrets.ps1"

# Apply Kubernetes resources
Write-Host "`nDeploying Kubernetes resources..." -ForegroundColor Cyan
kubectl apply -f "$PSScriptRoot\..\k8s"

# Install NGINX Ingress Controller
Write-Host "`nInstalling NGINX Ingress Controller..." -ForegroundColor Cyan
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx

# Wait for the NGINX Ingress Controller to get an external IP
Write-Host "`nWaiting for NGINX Ingress Controller to get an external IP..." -ForegroundColor Cyan
$externalIP = $null
$attempts = 0
$maxAttempts = 30

while (-not $externalIP -and $attempts -lt $maxAttempts) {
    $attempts++
    Start-Sleep -Seconds 10
    $externalIP = kubectl get service nginx-ingress-ingress-nginx-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
    if ($externalIP) {
        Write-Host "External IP assigned: $externalIP" -ForegroundColor Green
    }
    else {
        Write-Host "Waiting for external IP assignment (attempt $attempts of $maxAttempts)..." -ForegroundColor Yellow
    }
}

if (-not $externalIP) {
    Write-Host "Failed to get an external IP for the NGINX Ingress Controller after $maxAttempts attempts." -ForegroundColor Red
    Write-Host "Please check the service status manually with: kubectl get service nginx-ingress-ingress-nginx-controller" -ForegroundColor Red
    exit 1
}

# Install cert-manager
Write-Host "`nInstalling cert-manager..." -ForegroundColor Cyan
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

# Wait for cert-manager to be ready
Write-Host "`nWaiting for cert-manager to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Apply certificate issuer and ingress
Write-Host "`nApplying certificate issuer and ingress..." -ForegroundColor Cyan
kubectl apply -f "$PSScriptRoot\..\k8s\cert-issuer.yaml"
kubectl apply -f "$PSScriptRoot\..\k8s\n8n-ingress.yaml"

# Display deployment information
Write-Host "`n===================================================" -ForegroundColor Green
Write-Host "n8n Deployment completed!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green

Write-Host "`nNGINX Ingress External IP: $externalIP" -ForegroundColor Cyan
Write-Host "`nImportant Steps:" -ForegroundColor Yellow
Write-Host "1. Create a DNS A record for your domain (n8n.behooked.co) pointing to $externalIP" -ForegroundColor Yellow
Write-Host "2. After DNS propagation, access n8n at: https://n8n.behooked.co" -ForegroundColor Yellow

Write-Host "`nCheck deployment status:" -ForegroundColor Cyan
Write-Host "kubectl get all -n n8n" -ForegroundColor Cyan

Write-Host "`nCheck certificate status:" -ForegroundColor Cyan
Write-Host "kubectl get certificate -n n8n" -ForegroundColor Cyan

Write-Host "`nCheck n8n logs:" -ForegroundColor Cyan
Write-Host "kubectl logs -f deployment/n8n -n n8n" -ForegroundColor Cyan

Write-Host "`nRefer to the documentation in /docs for further information on monitoring and maintenance." -ForegroundColor Cyan
