# n8n Queue Mode Architecture

This document explains how queue mode works in our n8n deployment on Azure Kubernetes Service (AKS) and how it enhances scalability and performance.

## What is Queue Mode?

Queue mode in n8n allows for the separation of workflow triggers and their execution. This architecture provides several benefits:

1. **Scalability**: Multiple worker nodes can process executions in parallel
2. **Reliability**: Executions are stored in a queue and won't be lost if a worker crashes
3. **Resource Optimization**: Main n8n instance focuses on the UI and API, while dedicated workers handle executions
4. **Load Distribution**: Ensures high load from complex workflows doesn't impact the responsiveness of the main instance

## Our Queue Mode Implementation

Our AKS deployment implements queue mode with the following components:

### 1. Redis Queue

Redis serves as the message broker for workflow executions. When a workflow is triggered:

- The execution request is stored in Redis
- Worker nodes retrieve executions from the queue
- Results are stored back in the database

The Redis deployment includes:
- A dedicated Redis server
- Persistent storage via a PVC
- Internal service for n8n components to connect

### 2. Main n8n Instance

The main instance is responsible for:
- Serving the user interface
- Managing the REST API
- Handling webhook triggers and adding them to the queue
- Storing workflow definitions and execution data

It's configured with:
```yaml
- name: EXECUTIONS_MODE
  value: "queue"
- name: QUEUE_BULL_REDIS_HOST
  value: "redis-service.n8n.svc.cluster.local"
- name: QUEUE_BULL_REDIS_PORT
  value: "6379"
```

### 3. Worker Nodes

Worker nodes are dedicated to processing workflow executions from the queue. They:
- Poll the Redis queue for new executions
- Process workflows with all their actions and operations
- Update the database with execution results

Workers are horizontal pod autoscalers enabled to scale from 1 to 5 replicas based on CPU and memory usage.

## How Autoscaling Works

The Horizontal Pod Autoscaler (HPA) monitors worker resource usage:

```yaml
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
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

This configuration:
- Maintains at least 1 worker node at all times
- Scales up to 5 workers when needed
- Adds workers when CPU usage exceeds 70% or memory usage exceeds 80%
- Scales down when resource usage decreases

## Benefits of Our Architecture

1. **High Availability**: Multiple workers ensure executions continue even if one worker fails
2. **Cost Efficiency**: Scales resources based on actual demand
3. **Performance**: Main instance remains responsive even during high-load executions
4. **Isolation**: Problems in workflow executions don't affect the main n8n interface
5. **Resilience**: Failed executions can be retried without losing their state

## Monitoring Queue Performance

To monitor the queue performance:

```bash
# Check worker pod status
kubectl get pods -n n8n -l service=n8n-worker

# View worker logs
kubectl logs -l service=n8n-worker -n n8n

# Check autoscaler status
kubectl get hpa n8n-worker-hpa -n n8n

# Check Redis memory usage
kubectl exec -n n8n $(kubectl get pods -n n8n -l service=redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli info memory
```

## Tuning Queue Performance

You can fine-tune the queue performance by:

1. **Adjusting Redis configuration**:
   - Optimize memory settings
   - Enable persistence for reliability

2. **Worker resource allocation**:
   - Increase CPU/memory limits for complex workflows
   - Adjust autoscaling thresholds

3. **Queue settings in n8n**:
   - Configure retry behavior
   - Set maximum parallel executions per worker
