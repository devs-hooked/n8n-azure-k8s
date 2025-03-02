#!/bin/bash
# Script to validate n8n deployment on AKS

# Default namespace
NAMESPACE=${1:-"n8n"}

ERROR_COUNT=0
echo -e "\033[36mValidating n8n deployment in namespace $NAMESPACE...\033[0m"

# Function to check deployment status
check_deployment() {
    local DEPLOYMENT_NAME=$1
    
    DEPLOYMENT=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "\033[31m❌ Deployment $DEPLOYMENT_NAME not found\033[0m"
        return 1
    fi
    
    AVAILABLE_REPLICAS=$(echo $DEPLOYMENT | jq -r '.status.availableReplicas // 0')
    DESIRED_REPLICAS=$(echo $DEPLOYMENT | jq -r '.spec.replicas')
    
    if [ "$AVAILABLE_REPLICAS" -eq "$DESIRED_REPLICAS" ]; then
        echo -e "\033[32m✅ Deployment $DEPLOYMENT_NAME is healthy ($AVAILABLE_REPLICAS/$DESIRED_REPLICAS replicas available)\033[0m"
        return 0
    else
        echo -e "\033[31m❌ Deployment $DEPLOYMENT_NAME is not healthy ($AVAILABLE_REPLICAS/$DESIRED_REPLICAS replicas available)\033[0m"
        return 1
    fi
}

# Function to check PVC status
check_pvc() {
    local PVC_NAME=$1
    
    PVC=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "\033[31m❌ PVC $PVC_NAME not found\033[0m"
        return 1
    fi
    
    PHASE=$(echo $PVC | jq -r '.status.phase')
    
    if [ "$PHASE" == "Bound" ]; then
        echo -e "\033[32m✅ PVC $PVC_NAME is bound and ready\033[0m"
        return 0
    else
        echo -e "\033[31m❌ PVC $PVC_NAME is not in Bound state (current state: $PHASE)\033[0m"
        return 1
    fi
}

# Function to check service status
check_service() {
    local SERVICE_NAME=$1
    
    SERVICE=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "\033[31m❌ Service $SERVICE_NAME not found\033[0m"
        return 1
    fi
    
    SERVICE_TYPE=$(echo $SERVICE | jq -r '.spec.type')
    INGRESS=$(echo $SERVICE | jq -r '.status.loadBalancer.ingress // []')
    
    if [ "$SERVICE_TYPE" == "LoadBalancer" ] && [ "$INGRESS" == "[]" ]; then
        echo -e "\033[33m⚠️ Service $SERVICE_NAME doesn't have an external IP yet\033[0m"
        return 0
    fi
    
    echo -e "\033[32m✅ Service $SERVICE_NAME is available\033[0m"
    return 0
}

# Function to check secrets
check_secret() {
    local SECRET_NAME=$1
    
    kubectl get secret $SECRET_NAME -n $NAMESPACE &>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "\033[31m❌ Secret $SECRET_NAME not found\033[0m"
        return 1
    fi
    
    echo -e "\033[32m✅ Secret $SECRET_NAME is configured\033[0m"
    return 0
}

# Check deployments
echo -e "\n\033[33mChecking deployments...\033[0m"
check_deployment "postgres" || ((ERROR_COUNT++))
check_deployment "redis" || ((ERROR_COUNT++))
check_deployment "n8n" || ((ERROR_COUNT++))
check_deployment "n8n-worker" || ((ERROR_COUNT++))

# Check PVCs
echo -e "\n\033[33mChecking persistent volume claims...\033[0m"
check_pvc "postgres-data-claim" || ((ERROR_COUNT++))
check_pvc "redis-data-claim" || ((ERROR_COUNT++))

# Check services
echo -e "\n\033[33mChecking services...\033[0m"
check_service "postgres-service" || ((ERROR_COUNT++))
check_service "redis-service" || ((ERROR_COUNT++))
check_service "n8n" || ((ERROR_COUNT++))

# Check secrets
echo -e "\n\033[33mChecking secrets...\033[0m"
check_secret "postgres-secret" || ((ERROR_COUNT++))
check_secret "n8n-secret" || ((ERROR_COUNT++))

# Check if n8n is externally accessible
echo -e "\n\033[33mChecking n8n external access...\033[0m"
EXTERNAL_IP=$(kubectl get service n8n -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$EXTERNAL_IP" ]; then
    echo -e "\033[36mn8n is accessible at: http://$EXTERNAL_IP:5678\033[0m"
else
    echo -e "\033[33m⚠️ Waiting for external IP to be assigned to n8n service\033[0m"
fi

# Check if worker horizontal pod autoscaler exists
echo -e "\n\033[33mChecking autoscaler...\033[0m"
kubectl get hpa n8n-worker-hpa -n $NAMESPACE &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "\033[33m⚠️ HPA for n8n-worker not found\033[0m"
else
    echo -e "\033[32m✅ HPA for n8n-worker is configured\033[0m"
fi

# Summary
echo -e "\n--------------------------------"
if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "\033[32m✅ All checks passed! Your n8n deployment is healthy.\033[0m"
else
    echo -e "\033[31m❌ Validation completed with $ERROR_COUNT errors.\033[0m"
    echo -e "\033[33mPlease fix the issues listed above to ensure proper n8n functionality.\033[0m"
fi
echo -e "--------------------------------"

# Provide additional instructions
echo -e "\nNext steps:"
echo "1. Update the WEBHOOK_TUNNEL_URL in n8n-deployment.yaml with your actual IP or domain"
echo "2. Consider setting up SSL/TLS for secure access"
echo "3. Review scaling settings in n8n-autoscaler.yaml based on your workload"
