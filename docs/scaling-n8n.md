# Scaling n8n on Azure Kubernetes Service

This document outlines advanced scaling options for n8n deployments on Azure Kubernetes Service (AKS).

## Understanding n8n Execution Modes

n8n supports multiple execution modes that affect how workflow executions are handled:

### Regular Mode (Default)

In regular mode, each n8n instance handles both the UI/API and workflow executions. This is suitable for smaller deployments but can be limited in scaling.

### Queue Mode

Queue mode separates the n8n system into different components:

1. **Main Process**: Handles the UI, API, and webhook triggers
2. **Worker Processes**: Handle workflow executions, allowing for horizontal scaling

## Configuring Queue Mode for AKS

Queue mode in n8n requires:

1. A message broker (Redis)
2. Multiple n8n instances configured as main and workers

### Step 1: Deploy Redis

Add a Redis deployment to your AKS cluster:

```yaml
# k8s/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: n8n
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

### Step 2: Configure n8n Main Instance

Modify your n8n deployment to enable queue mode:

```yaml
# k8s/n8n-main-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-main
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n-main
  template:
    metadata:
      labels:
        app: n8n-main
    spec:
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        env:
        - name: DB_TYPE
          value: "postgresdb"
        - name: DB_POSTGRESDB_HOST
          value: "postgres-service"
        - name: DB_POSTGRESDB_PORT
          value: "5432"
        - name: DB_POSTGRESDB_DATABASE
          value: "n8n"
        - name: DB_POSTGRESDB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: DB_POSTGRESDB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: N8N_ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: n8n-secret
              key: N8N_ENCRYPTION_KEY
        # Queue mode settings
        - name: EXECUTIONS_MODE
          value: "queue"
        - name: QUEUE_BULL_REDIS_HOST
          value: "redis-service"
        - name: QUEUE_BULL_REDIS_PORT
          value: "6379"
        - name: N8N_PROCESS
          value: "main"
        ports:
        - containerPort: 5678
```

### Step 3: Deploy Worker Instances

Create worker deployments to handle workflow executions:

```yaml
# k8s/n8n-worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-worker
  namespace: n8n
spec:
  replicas: 2  # Adjust based on your workload
  selector:
    matchLabels:
      app: n8n-worker
  template:
    metadata:
      labels:
        app: n8n-worker
    spec:
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        env:
        - name: DB_TYPE
          value: "postgresdb"
        - name: DB_POSTGRESDB_HOST
          value: "postgres-service"
        - name: DB_POSTGRESDB_PORT
          value: "5432"
        - name: DB_POSTGRESDB_DATABASE
          value: "n8n"
        - name: DB_POSTGRESDB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: DB_POSTGRESDB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: N8N_ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: n8n-secret
              key: N8N_ENCRYPTION_KEY
        # Queue mode settings
        - name: EXECUTIONS_MODE
          value: "queue"
        - name: QUEUE_BULL_REDIS_HOST
          value: "redis-service"
        - name: QUEUE_BULL_REDIS_PORT
          value: "6379"
        - name: N8N_PROCESS
          value: "worker"
```

## Horizontal Pod Autoscaling (HPA)

AKS supports automatic scaling of n8n worker pods based on CPU or memory usage:

```yaml
# k8s/n8n-worker-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: n8n-worker-hpa
  namespace: n8n
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: n8n-worker
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Performance Tuning

### Resource Allocation

Optimize resource allocation based on your workload:

```yaml
resources:
  requests:
    cpu: 500m    # Minimum 0.5 CPU cores
    memory: 1Gi  # Minimum 1GB memory
  limits:
    cpu: 2       # Maximum 2 CPU cores
    memory: 2Gi  # Maximum 2GB memory
```

### Database Optimization

For larger n8n deployments, consider:

1. Using Azure Database for PostgreSQL instead of self-hosted
2. Implementing database connection pooling
3. Regular database maintenance and optimization

## Monitoring

Implement monitoring for your n8n deployment:

1. Enable Azure Monitor for AKS
2. Deploy Prometheus and Grafana for detailed metrics
3. Set up alerts for resource usage and pod health

## References

- [n8n Queue Mode Documentation](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [Azure Kubernetes Service Scaling](https://docs.microsoft.com/en-us/azure/aks/concepts-scale)
- [Kubernetes Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
