# PowerShell script to validate n8n deployment on AKS
param (
    [string]$Namespace = "n8n"
)

$ErrorCount = 0
Write-Host "Validating n8n deployment in namespace $Namespace..." -ForegroundColor Cyan

# Function to check deployment status
function Check-Deployment {
    param (
        [string]$DeploymentName
    )
    
    $Deployment = kubectl get deployment $DeploymentName -n $Namespace -o json | ConvertFrom-Json
    
    if (-not $Deployment) {
        Write-Host "❌ Deployment $DeploymentName not found" -ForegroundColor Red
        return $false
    }
    
    $AvailableReplicas = $Deployment.status.availableReplicas
    $DesiredReplicas = $Deployment.spec.replicas
    
    if ($AvailableReplicas -eq $DesiredReplicas) {
        Write-Host "✅ Deployment $DeploymentName is healthy ($AvailableReplicas/$DesiredReplicas replicas available)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Deployment $DeploymentName is not healthy ($AvailableReplicas/$DesiredReplicas replicas available)" -ForegroundColor Red
        return $false
    }
}

# Function to check PVC status
function Check-PVC {
    param (
        [string]$PVCName
    )
    
    $PVC = kubectl get pvc $PVCName -n $Namespace -o json | ConvertFrom-Json
    
    if (-not $PVC) {
        Write-Host "❌ PVC $PVCName not found" -ForegroundColor Red
        return $false
    }
    
    if ($PVC.status.phase -eq "Bound") {
        Write-Host "✅ PVC $PVCName is bound and ready" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ PVC $PVCName is not in Bound state (current state: $($PVC.status.phase))" -ForegroundColor Red
        return $false
    }
}

# Function to check service status
function Check-Service {
    param (
        [string]$ServiceName
    )
    
    $Service = kubectl get service $ServiceName -n $Namespace -o json | ConvertFrom-Json
    
    if (-not $Service) {
        Write-Host "❌ Service $ServiceName not found" -ForegroundColor Red
        return $false
    }
    
    if ($Service.spec.type -eq "LoadBalancer" -and (-not $Service.status.loadBalancer.ingress)) {
        Write-Host "⚠️ Service $ServiceName doesn't have an external IP yet" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "✅ Service $ServiceName is available" -ForegroundColor Green
    return $true
}

# Function to check secrets
function Check-Secret {
    param (
        [string]$SecretName
    )
    
    $Secret = kubectl get secret $SecretName -n $Namespace 2>&1
    
    if ($Secret -match "not found") {
        Write-Host "❌ Secret $SecretName not found" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Secret $SecretName is configured" -ForegroundColor Green
    return $true
}

# Check deployments
Write-Host "`nChecking deployments..." -ForegroundColor Yellow
$DeploymentResults = @(
    (Check-Deployment -DeploymentName "postgres"),
    (Check-Deployment -DeploymentName "redis"),
    (Check-Deployment -DeploymentName "n8n"),
    (Check-Deployment -DeploymentName "n8n-worker")
)
$ErrorCount += ($DeploymentResults | Where-Object { $_ -eq $false }).Count

# Check PVCs
Write-Host "`nChecking persistent volume claims..." -ForegroundColor Yellow
$PVCResults = @(
    (Check-PVC -PVCName "postgres-data-claim"),
    (Check-PVC -PVCName "redis-data-claim")
)
$ErrorCount += ($PVCResults | Where-Object { $_ -eq $false }).Count

# Check services
Write-Host "`nChecking services..." -ForegroundColor Yellow
$ServiceResults = @(
    (Check-Service -ServiceName "postgres-service"),
    (Check-Service -ServiceName "redis-service"),
    (Check-Service -ServiceName "n8n")
)
$ErrorCount += ($ServiceResults | Where-Object { $_ -eq $false }).Count

# Check secrets
Write-Host "`nChecking secrets..." -ForegroundColor Yellow
$SecretResults = @(
    (Check-Secret -SecretName "postgres-secret"),
    (Check-Secret -SecretName "n8n-secret")
)
$ErrorCount += ($SecretResults | Where-Object { $_ -eq $false }).Count

# Check if n8n is externally accessible
Write-Host "`nChecking n8n external access..." -ForegroundColor Yellow
$n8nService = kubectl get service n8n -n $Namespace -o json | ConvertFrom-Json
if ($n8nService.status.loadBalancer.ingress) {
    $ExternalIP = $n8nService.status.loadBalancer.ingress[0].ip
    Write-Host "n8n is accessible at: http://$ExternalIP`:5678" -ForegroundColor Cyan
} else {
    Write-Host "⚠️ Waiting for external IP to be assigned to n8n service" -ForegroundColor Yellow
}

# Check if worker horizontal pod autoscaler exists
Write-Host "`nChecking autoscaler..." -ForegroundColor Yellow
$HPA = kubectl get hpa n8n-worker-hpa -n $Namespace 2>&1
if ($HPA -match "not found") {
    Write-Host "⚠️ HPA for n8n-worker not found" -ForegroundColor Yellow
} else {
    Write-Host "✅ HPA for n8n-worker is configured" -ForegroundColor Green
}

# Summary
Write-Host "`n--------------------------------"
if ($ErrorCount -eq 0) {
    Write-Host "✅ All checks passed! Your n8n deployment is healthy." -ForegroundColor Green
} else {
    Write-Host "❌ Validation completed with $ErrorCount errors." -ForegroundColor Red
    Write-Host "Please fix the issues listed above to ensure proper n8n functionality." -ForegroundColor Yellow
}
Write-Host "--------------------------------"

# Provide additional instructions
Write-Host "`nNext steps:"
Write-Host "1. Update the WEBHOOK_TUNNEL_URL in n8n-deployment.yaml with your actual IP or domain"
Write-Host "2. Consider setting up SSL/TLS using setup-certificates.ps1"
Write-Host "3. Review scaling settings in n8n-autoscaler.yaml based on your workload"
