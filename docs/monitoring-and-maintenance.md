# Monitoring and Maintenance for n8n on AKS

This guide covers best practices for monitoring and maintaining your n8n deployment on Azure Kubernetes Service.

## Monitoring Your Deployment

### Basic Monitoring Commands

```powershell
# Check pod status
kubectl get pods -n n8n

# View n8n logs
kubectl logs -f deployment/n8n -n n8n

# View worker logs
kubectl logs -f deployment/n8n-worker -n n8n

# Check autoscaler status
kubectl get hpa -n n8n

# Check all services
kubectl get services -n n8n
```

### Azure Monitor Integration

You can integrate your AKS cluster with Azure Monitor for more comprehensive monitoring:

1. In the Azure Portal, navigate to your AKS cluster
2. Go to "Monitoring" → "Insights"
3. Enable Container Insights

### Alert Setup

Configure alerts for critical metrics:

1. CPU usage exceeding 80%
2. Memory usage exceeding 85%
3. Pod restarts
4. Persistent volume utilization

## Maintenance Tasks

### Upgrading n8n

To upgrade n8n to a newer version:

```powershell
# Update the main n8n instance
kubectl set image deployment/n8n n8n=n8nio/n8n:latest -n n8n

# Update worker instances
kubectl set image deployment/n8n-worker n8n-worker=n8nio/n8n:latest -n n8n

# Restart the deployments to apply changes
kubectl rollout restart deployment/n8n -n n8n
kubectl rollout restart deployment/n8n-worker -n n8n
```

For specific versions, replace `latest` with the desired version tag, e.g., `n8nio/n8n:0.214.0`.

### Database Backup

Regularly back up your PostgreSQL database:

```powershell
# Get the PostgreSQL pod name
$POSTGRES_POD = kubectl get pods -n n8n -l service=postgres-n8n -o jsonpath='{.items[0].metadata.name}'

# Create a backup
kubectl exec -n n8n $POSTGRES_POD -- pg_dumpall -c -U postgres > n8n_db_backup_$(Get-Date -Format 'yyyyMMdd').sql
```

### Restore from Backup

To restore from a backup:

```powershell
# Get the PostgreSQL pod name
$POSTGRES_POD = kubectl get pods -n n8n -l service=postgres-n8n -o jsonpath='{.items[0].metadata.name}'

# Copy the backup file to the pod
kubectl cp n8n_db_backup.sql n8n/$POSTGRES_POD:/tmp/

# Restore from the backup
kubectl exec -n n8n $POSTGRES_POD -- psql -U postgres -f /tmp/n8n_db_backup.sql
```

### Certificate Renewal

Let's Encrypt certificates are valid for 90 days and automatically renewed by cert-manager. To check certificate status:

```powershell
kubectl get certificate -n n8n
```

If you need to manually renew a certificate:

```powershell
kubectl delete certificate n8n-tls-secret -n n8n
kubectl apply -f k8s/n8n-ingress.yaml
```

## Scaling Resources

### Scaling Worker Nodes

To adjust the number of worker nodes:

```powershell
# Edit the HPA configuration
kubectl edit hpa n8n-worker-hpa -n n8n
```

Update the `minReplicas` and `maxReplicas` values to your desired numbers.

### Scaling Cluster Nodes

To scale the underlying AKS cluster:

```powershell
az aks scale --resource-group n8n-aks-rg --name n8n-aks-cluster --node-count 3
```

### Adjusting Resource Limits

To adjust resource limits for n8n:

```powershell
kubectl edit deployment n8n -n n8n
```

Update the `resources.limits` and `resources.requests` sections as needed.

## Troubleshooting

### Common Issues and Solutions

#### Database Connection Issues

If n8n can't connect to PostgreSQL:

```powershell
# Check if PostgreSQL pod is running
kubectl get pods -n n8n -l service=postgres-n8n

# Verify PostgreSQL service
kubectl describe service postgres-service -n n8n

# Check n8n logs for connection errors
kubectl logs deployment/n8n -n n8n | Select-String "database"
```

#### Worker Scaling Issues

If workers aren't scaling as expected:

```powershell
# Check HPA status and events
kubectl describe hpa n8n-worker-hpa -n n8n
```

#### Redis Connection Issues

If queue mode isn't working:

```powershell
# Check if Redis is running
kubectl get pods -n n8n -l service=redis

# Verify Redis service
kubectl describe service redis-service -n n8n

# Check logs for Redis connection issues
kubectl logs deployment/n8n -n n8n | Select-String "redis|queue"
```

## Performance Optimization

### Redis Persistence

For better performance, consider configuring Redis with persistence options:

```yaml
# Add to redis-deployment.yaml
command: ["redis-server", "--appendonly", "yes"]
```

### Database Tuning

Tune PostgreSQL for better performance:

```powershell
# Edit the PostgreSQL ConfigMap (create if needed)
kubectl create configmap postgres-config -n n8n --from-literal=postgres.conf="
max_connections=100
shared_buffers=256MB
effective_cache_size=768MB
maintenance_work_mem=64MB
checkpoint_completion_target=0.7
wal_buffers=7864kB
default_statistics_target=100
random_page_cost=1.1
effective_io_concurrency=200
"
```

Then update the Postgres deployment to use this ConfigMap.
