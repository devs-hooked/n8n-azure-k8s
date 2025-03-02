# PowerShell script to generate Kubernetes secrets for n8n deployment

# Create output directory if it doesn't exist
$OutputDir = "../k8s/generated"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir
}

# Function to generate a random password
function Generate-RandomPassword {
    param (
        [int]$Length = 16
    )
    $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?'
    $Random = New-Object System.Random
    $Password = 1..$Length | ForEach-Object { $CharSet[$Random.Next(0, $CharSet.Length)] }
    return ($Password -join '')
}

# Function to base64 encode a string
function Base64Encode {
    param (
        [string]$InputString
    )
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    return [Convert]::ToBase64String($Bytes)
}

# Generate random values for secrets
$PostgresUser = "postgres"
$PostgresPassword = Generate-RandomPassword -Length 20
$PostgresNonRootUser = "n8n"
$PostgresNonRootPassword = Generate-RandomPassword -Length 20
$N8nEncryptionKey = Generate-RandomPassword -Length 32

# Base64 encode the values
$PostgresUserEncoded = Base64Encode -InputString $PostgresUser
$PostgresPasswordEncoded = Base64Encode -InputString $PostgresPassword
$PostgresNonRootUserEncoded = Base64Encode -InputString $PostgresNonRootUser
$PostgresNonRootPasswordEncoded = Base64Encode -InputString $PostgresNonRootPassword
$N8nEncryptionKeyEncoded = Base64Encode -InputString $N8nEncryptionKey

# Generate the secrets YAML file
$SecretsYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: n8n
type: Opaque
data:
  POSTGRES_USER: $PostgresUserEncoded
  POSTGRES_PASSWORD: $PostgresPasswordEncoded
  POSTGRES_NON_ROOT_USER: $PostgresNonRootUserEncoded
  POSTGRES_NON_ROOT_PASSWORD: $PostgresNonRootPasswordEncoded
---
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secret
  namespace: n8n
type: Opaque
data:
  N8N_ENCRYPTION_KEY: $N8nEncryptionKeyEncoded
"@

# Write to file
$SecretsYaml | Out-File -FilePath "$OutputDir/secrets.yaml" -Encoding utf8

Write-Host "Generated secrets file: $OutputDir/secrets.yaml"
Write-Host ""
Write-Host "Secret values (keep these secure):"
Write-Host "PostgreSQL Root User: $PostgresUser"
Write-Host "PostgreSQL Root Password: $PostgresPassword"
Write-Host "PostgreSQL n8n User: $PostgresNonRootUser"
Write-Host "PostgreSQL n8n Password: $PostgresNonRootPassword"
Write-Host "n8n Encryption Key: $N8nEncryptionKey"
