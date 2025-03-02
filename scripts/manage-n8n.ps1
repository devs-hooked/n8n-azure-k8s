# n8n Management Script for Azure Kubernetes Service
# This script provides common management commands for n8n deployed on AKS

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("status", "logs", "scale", "restart", "certificate", "backup", "help")]
    [string]$Command = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$Component = "",
    
    [Parameter(Mandatory=$false)]
    [int]$Replicas = 0
)

$namespace = "n8n"

function Show-Usage {
    Write-Host "n8n Management Script for Azure Kubernetes Service" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: ./manage-n8n.ps1 -Command <command> [-Component <component>] [-Replicas <number>]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Green
    Write-Host "  status      - Show status of all n8n components"
    Write-Host "  logs        - View logs for a specific component (requires -Component)"
    Write-Host "  scale       - Scale worker nodes (requires -Replicas)"
    Write-Host "  restart     - Restart a specific component (requires -Component)"
    Write-Host "  certificate - Check certificate status"
    Write-Host "  backup      - Create a backup of PostgreSQL data"
    Write-Host "  help        - Show this help message"
    Write-Host ""
    Write-Host "Components:" -ForegroundColor Green
    Write-Host "  n8n         - Main n8n application"
    Write-Host "  worker      - n8n worker nodes"
    Write-Host "  postgres    - PostgreSQL database"
    Write-Host "  redis       - Redis server"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Magenta
    Write-Host "  ./manage-n8n.ps1 -Command status"
    Write-Host "  ./manage-n8n.ps1 -Command logs -Component n8n"
    Write-Host "  ./manage-n8n.ps1 -Command scale -Replicas 3"
    Write-Host "  ./manage-n8n.ps1 -Command restart -Component postgres"
    Write-Host ""
}

function Check-Status {
    Write-Host "Checking n8n deployment status in namespace $namespace..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Deployments:" -ForegroundColor Green
    kubectl get deployments -n $namespace
    Write-Host ""
    
    Write-Host "Pods:" -ForegroundColor Green
    kubectl get pods -n $namespace
    Write-Host ""
    
    Write-Host "Services:" -ForegroundColor Green
    kubectl get services -n $namespace
    Write-Host ""
    
    Write-Host "Persistent Volume Claims:" -ForegroundColor Green
    kubectl get pvc -n $namespace
    Write-Host ""
    
    Write-Host "Ingress:" -ForegroundColor Green
    kubectl get ingress -n $namespace
    Write-Host ""
    
    Write-Host "Horizontal Pod Autoscaler:" -ForegroundColor Green
    kubectl get hpa -n $namespace
    Write-Host ""
    
    Write-Host "Certificates:" -ForegroundColor Green
    kubectl get certificates -n $namespace
    Write-Host ""
}

function View-Logs {
    if (-not $Component) {
        Write-Host "Error: Component parameter is required for logs command" -ForegroundColor Red
        Write-Host "Example: ./manage-n8n.ps1 -Command logs -Component n8n" -ForegroundColor Yellow
        return
    }
    
    $deployment = ""
    switch ($Component) {
        "n8n" { $deployment = "n8n" }
        "worker" { $deployment = "n8n-worker" }
        "postgres" { $deployment = "postgres" }
        "redis" { $deployment = "redis" }
        default {
            Write-Host "Error: Unknown component: $Component" -ForegroundColor Red
            Write-Host "Valid components are: n8n, worker, postgres, redis" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "Viewing logs for $deployment in namespace $namespace..." -ForegroundColor Cyan
    kubectl logs -n $namespace deployment/$deployment --tail=100
}

function Scale-Workers {
    if ($Replicas -lt 1) {
        Write-Host "Error: Replicas parameter must be at least 1" -ForegroundColor Red
        Write-Host "Example: ./manage-n8n.ps1 -Command scale -Replicas 3" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Scaling n8n-worker deployment to $Replicas replicas..." -ForegroundColor Cyan
    kubectl scale deployment n8n-worker -n $namespace --replicas=$Replicas
    
    # Wait for the scaling to complete
    Write-Host "Waiting for scaling operation to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Show the result
    kubectl get pods -n $namespace -l app=n8n-worker
}

function Restart-Component {
    if (-not $Component) {
        Write-Host "Error: Component parameter is required for restart command" -ForegroundColor Red
        Write-Host "Example: ./manage-n8n.ps1 -Command restart -Component n8n" -ForegroundColor Yellow
        return
    }
    
    $deployment = ""
    switch ($Component) {
        "n8n" { $deployment = "n8n" }
        "worker" { $deployment = "n8n-worker" }
        "postgres" { $deployment = "postgres" }
        "redis" { $deployment = "redis" }
        default {
            Write-Host "Error: Unknown component: $Component" -ForegroundColor Red
            Write-Host "Valid components are: n8n, worker, postgres, redis" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "Restarting $deployment in namespace $namespace..." -ForegroundColor Cyan
    kubectl rollout restart deployment/$deployment -n $namespace
    
    # Wait for the restart to complete
    Write-Host "Waiting for restart operation to complete..." -ForegroundColor Yellow
    kubectl rollout status deployment/$deployment -n $namespace
}

function Check-Certificate {
    Write-Host "Checking certificate status in namespace $namespace..." -ForegroundColor Cyan
    kubectl get certificate -n $namespace
    Write-Host ""
    
    Write-Host "Certificate details:" -ForegroundColor Green
    kubectl describe certificate n8n-tls-secret -n $namespace
}

function Create-Backup {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = "postgres-backup-$timestamp.sql"
    
    Write-Host "Creating backup of PostgreSQL database..." -ForegroundColor Cyan
    Write-Host "This may take a few minutes depending on database size." -ForegroundColor Yellow
    
    # Get the postgres pod name
    $postgresPod = kubectl get pods -n $namespace -l app=postgres -o jsonpath="{.items[0].metadata.name}"
    
    # Run pg_dump inside the pod
    kubectl exec -n $namespace $postgresPod -- pg_dump -U postgres n8n > $backupFile
    
    if ($?) {
        Write-Host "Backup created successfully: $backupFile" -ForegroundColor Green
    } else {
        Write-Host "Failed to create backup" -ForegroundColor Red
    }
}

# Main script logic
switch ($Command) {
    "status" { Check-Status }
    "logs" { View-Logs }
    "scale" { Scale-Workers }
    "restart" { Restart-Component }
    "certificate" { Check-Certificate }
    "backup" { Create-Backup }
    "help" { Show-Usage }
    default { Show-Usage }
}
