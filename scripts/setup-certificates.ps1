# PowerShell script to set up SSL/TLS certificates for n8n
param (
    [Parameter(Mandatory=$true)]
    [string]$Namespace = "n8n",
    
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$true)]
    [string]$Email,
    
    [string]$Environment = "prod"
)

# Check if cert-manager is installed
$CERT_MANAGER_STATUS = kubectl get pods -n cert-manager -l app=cert-manager 2>&1
if ($CERT_MANAGER_STATUS -match 'No resources found') {
    Write-Host "Cert-manager not found. Installing..."
    
    # Add the Jetstack Helm repository
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Install cert-manager
    helm install cert-manager jetstack/cert-manager `
        --namespace cert-manager `
        --create-namespace `
        --version v1.11.0 `
        --set installCRDs=true
    
    # Wait for cert-manager to be ready
    Write-Host "Waiting for cert-manager to be ready..."
    Start-Sleep -Seconds 60
} else {
    Write-Host "Cert-manager is already installed."
}

# Create ClusterIssuer for Let's Encrypt
$SERVER = $Environment -eq "prod" ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"
$ISSUER_NAME = "letsencrypt-$Environment"

$ISSUER_YAML = @"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $ISSUER_NAME
spec:
  acme:
    email: $Email
    server: $SERVER
    privateKeySecretRef:
      name: letsencrypt-$Environment-key
    solvers:
    - http01:
        ingress:
          class: nginx
"@

$ISSUER_YAML | Out-File -FilePath "cert-issuer-temp.yaml" -Encoding utf8
kubectl apply -f "cert-issuer-temp.yaml"
Remove-Item -Path "cert-issuer-temp.yaml"

# Update the ingress to use the new ClusterIssuer
$INGRESS_YAML = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: n8n-ingress
  namespace: $Namespace
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "$ISSUER_NAME"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - $Domain
    secretName: n8n-tls-$Environment
  rules:
  - host: $Domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: n8n
            port:
              number: 5678
"@

$INGRESS_YAML | Out-File -FilePath "ingress-temp.yaml" -Encoding utf8
kubectl apply -f "ingress-temp.yaml"
Remove-Item -Path "ingress-temp.yaml"

# Update the WEBHOOK_TUNNEL_URL in n8n deployment
$N8N_DEPLOYMENT = kubectl get deployment n8n -n $Namespace -o yaml
$N8N_DEPLOYMENT = $N8N_DEPLOYMENT -replace "WEBHOOK_TUNNEL_URL: `"http://YOUR_DOMAIN_OR_IP:5678/`"", "WEBHOOK_TUNNEL_URL: `"https://$Domain/`""
$N8N_DEPLOYMENT | Out-File -FilePath "n8n-deployment-temp.yaml" -Encoding utf8
kubectl apply -f "n8n-deployment-temp.yaml"
Remove-Item -Path "n8n-deployment-temp.yaml"

Write-Host "SSL/TLS certificates setup complete. Certificate provisioning will happen in the background."
Write-Host "You can check the status with: kubectl get certificate -n $Namespace"
Write-Host "Your n8n instance will be available at: https://$Domain"
