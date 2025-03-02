#!/bin/bash
# Bash script to generate Kubernetes secrets for n8n deployment

# Create output directory if it doesn't exist
OUTPUT_DIR="../k8s/generated"
mkdir -p "$OUTPUT_DIR"

# Function to generate a random password
generate_random_password() {
    local length=${1:-16}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+[]{}|;:,.<>?' | head -c "$length"
}

# Generate random values for secrets
POSTGRES_USER="postgres"
POSTGRES_PASSWORD=$(generate_random_password 20)
POSTGRES_NON_ROOT_USER="n8n"
POSTGRES_NON_ROOT_PASSWORD=$(generate_random_password 20)
N8N_ENCRYPTION_KEY=$(generate_random_password 32)

# Create the secrets YAML file
cat > "$OUTPUT_DIR/secrets.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: n8n
type: Opaque
data:
  POSTGRES_USER: $(echo -n $POSTGRES_USER | base64)
  POSTGRES_PASSWORD: $(echo -n $POSTGRES_PASSWORD | base64)
  POSTGRES_NON_ROOT_USER: $(echo -n $POSTGRES_NON_ROOT_USER | base64)
  POSTGRES_NON_ROOT_PASSWORD: $(echo -n $POSTGRES_NON_ROOT_PASSWORD | base64)
---
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secret
  namespace: n8n
type: Opaque
data:
  N8N_ENCRYPTION_KEY: $(echo -n $N8N_ENCRYPTION_KEY | base64)
EOF

echo "Generated secrets file: $OUTPUT_DIR/secrets.yaml"
echo ""
echo "Secret values (keep these secure):"
echo "PostgreSQL Root User: $POSTGRES_USER"
echo "PostgreSQL Root Password: $POSTGRES_PASSWORD"
echo "PostgreSQL n8n User: $POSTGRES_NON_ROOT_USER"
echo "PostgreSQL n8n Password: $POSTGRES_NON_ROOT_PASSWORD"
echo "n8n Encryption Key: $N8N_ENCRYPTION_KEY"
