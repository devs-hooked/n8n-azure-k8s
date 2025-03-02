# Setting Up n8n in Queue Mode on Azure Kubernetes Service

This guide explains how to set up n8n in queue mode on Azure Kubernetes Service (AKS) for improved scalability and performance.

## What is Queue Mode?

n8n's queue mode is designed for higher scalability where workflow executions are processed through a queue. This allows for:

- Horizontal scaling of execution workers
- Better performance under high loads
- Improved reliability and fault tolerance
- Distribution of workflow executions across multiple workers

## Architecture

When running n8n in queue mode on AKS, the architecture includes:

1. **Main n8n instance**: Handles the UI, API, and workflow management
2. **n8n workers**: Process workflow executions from the queue
3. **Redis**: Acts as the queue system
4. **PostgreSQL**: Stores workflow definitions, credentials, and execution data
5. **Kubernetes HPA**: Automatically scales workers based on load

## Deployment Components

Our deployment includes:

- `n8n-deployment.yaml`: Main n8n instance
- `n8n-worker-deployment.yaml`: Worker instances that process executions
- `redis-deployment.yaml`: Redis for the queue
- `postgres-deployment.yaml`: PostgreSQL database
- `n8n-autoscaler.yaml`: Horizontal Pod Autoscaler for workers

## Scaling Configuration

The n8n workers are configured to automatically scale:

- Minimum replicas: 2
- Maximum replicas: 5
- CPU target utilization: 70%
- Memory target utilization: 80%

## Deployment Instructions

1. Follow the standard deployment process using `deploy-aks.ps1`
2. After deployment, get the external IP:
   ```
   kubectl get service n8n -n n8n
   ```
3. Update the `WEBHOOK_TUNNEL_URL` in `n8n-deployment.yaml` with your actual IP or domain:
   ```yaml
   - name: WEBHOOK_TUNNEL_URL
     value: "http://YOUR_ACTUAL_IP_OR_DOMAIN:5678/"
   ```
4. Reapply the configuration:
   ```
   kubectl apply -f k8s/n8n-deployment.yaml
   ```

## Monitoring

Monitor the status of your workers:

```bash
# Get worker pods
kubectl get pods -l service=n8n-worker -n n8n

# Check autoscaler status
kubectl get hpa n8n-worker-hpa -n n8n

# View worker logs
kubectl logs -f -l service=n8n-worker -n n8n
```

## Tuning Performance

You can adjust several parameters to optimize performance:

1. **Worker count**: Modify min/max replicas in `n8n-autoscaler.yaml`
2. **Resource limits**: Adjust CPU/memory in the deployment files
3. **Queue settings**: Add additional Redis configuration as needed

## Troubleshooting

If you encounter issues:

1. Check that Redis is running:
   ```
   kubectl get pods -l service=redis -n n8n
   ```

2. Verify worker logs:
   ```
   kubectl logs -f -l service=n8n-worker -n n8n
   ```

3. Ensure environment variables are set correctly in both main n8n and worker deployments
