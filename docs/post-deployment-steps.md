# Post-Deployment Steps for n8n on AKS

After the initial deployment completes, follow these steps to finalize your n8n setup with SSL/TLS support and proper domain configuration.

## 1. Install NGINX Ingress Controller

```powershell
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the NGINX ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx
```

## 2. Get the External IP for NGINX Ingress Controller

```powershell
# Check the status and get the external IP
kubectl get service nginx-ingress-ingress-nginx-controller
```

Wait until an external IP is assigned. This may take a few minutes.

## 3. Configure DNS for Your Domain

Create a DNS A record for `n8n.behooked.co` pointing to the external IP address obtained in the previous step.

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | n8n | [EXTERNAL_IP] | 300 |

## 4. Install cert-manager for SSL/TLS Certificates

```powershell
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager `
    --namespace cert-manager `
    --create-namespace `
    --set installCRDs=true
```

## 5. Apply Certificate Issuer and Ingress Configurations

```powershell
# Apply the certificate issuer
kubectl apply -f k8s/cert-issuer.yaml

# Apply the ingress configuration
kubectl apply -f k8s/n8n-ingress.yaml
```

## 6. Verify Certificate Status

```powershell
# Check certificate status
kubectl get certificates -n n8n
```

Wait until the certificate shows as "Ready: True".

## 7. Access Your n8n Instance

Once the certificate is ready and DNS has propagated, you can access your n8n instance at:

https://n8n.behooked.co

## Troubleshooting

### Check Certificate Status
```powershell
kubectl describe certificate n8n-tls-secret -n n8n
```

### Check Ingress Status
```powershell
kubectl describe ingress n8n-ingress -n n8n
```

### View Certificate Issuer Logs
```powershell
kubectl logs -n cert-manager -l app=cert-manager
```

### Verify n8n Deployment
```powershell
kubectl get pods -n n8n
kubectl logs -l service=n8n -n n8n
```
