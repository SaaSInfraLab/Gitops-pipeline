#!/bin/bash
# Create db-credentials secret from AWS Secrets Manager
# This is a fallback if Secrets Store CSI Driver is not available

set -e

NAMESPACE="${1:-platform}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Creating db-credentials Secret"
echo "Namespace: $NAMESPACE"
echo "=========================================="
echo ""

# Get secret ARN from infra_version.yaml or AWS
if [ -f "$SCRIPT_DIR/../infra_version.yaml" ]; then
    SECRET_ARN=$(grep -A 1 "rds_secret_arn:" "$SCRIPT_DIR/../infra_version.yaml" | grep -v "rds_secret_arn:" | tr -d ' "')
    SECRET_NAME=$(grep -A 1 "rds_secret_name:" "$SCRIPT_DIR/../infra_version.yaml" | grep -v "rds_secret_name:" | tr -d ' "')
    RDS_ENDPOINT=$(grep -A 1 "rds_address:" "$SCRIPT_DIR/../infra_version.yaml" | grep -v "rds_address:" | tr -d ' "')
    RDS_PORT=$(grep -A 1 "rds_port:" "$SCRIPT_DIR/../infra_version.yaml" | grep -v "rds_port:" | tr -d ' "')
    RDS_DB_NAME=$(grep -A 1 "rds_database_name:" "$SCRIPT_DIR/../infra_version.yaml" | grep -v "rds_database_name:" | tr -d ' "')
    RDS_USERNAME=$(grep -A 1 "rds_instance_username:" "$SCRIPT_DIR/../infra_version.yaml" | grep -v "rds_instance_username:" | tr -d ' "')
fi

if [ -z "$SECRET_ARN" ]; then
    echo "⚠️  Could not get secret ARN from infra_version.yaml"
    echo "   Trying to get from AWS..."
    
    # Try to find RDS secret
    SECRET_ARN=$(aws secretsmanager list-secrets --query "SecretList[?contains(Name, 'rds-db-credentials')].ARN" --output text | head -n1 || echo "")
    
    if [ -z "$SECRET_ARN" ]; then
        echo "❌ Could not find RDS secret in AWS Secrets Manager"
        exit 1
    fi
fi

echo "Secret ARN: $SECRET_ARN"
echo ""

# Get secret value from AWS Secrets Manager
echo "Retrieving secret from AWS Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text 2>/dev/null || echo "")

if [ -z "$SECRET_JSON" ]; then
    echo "❌ Failed to retrieve secret from AWS Secrets Manager"
    exit 1
fi

# Parse JSON (using jq if available, or basic parsing)
if command -v jq &> /dev/null; then
    DB_USERNAME=$(echo "$SECRET_JSON" | jq -r '.username // empty')
    DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.password // empty')
    DB_HOST=$(echo "$SECRET_JSON" | jq -r '.host // empty')
    DB_PORT=$(echo "$SECRET_JSON" | jq -r '.port // empty')
    DB_NAME=$(echo "$SECRET_JSON" | jq -r '.dbname // .dbName // empty')
else
    # Basic parsing without jq
    DB_USERNAME=$(echo "$SECRET_JSON" | grep -o '"username"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    DB_PASSWORD=$(echo "$SECRET_JSON" | grep -o '"password"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    DB_HOST=$(echo "$SECRET_JSON" | grep -o '"host"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    DB_PORT=$(echo "$SECRET_JSON" | grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "")
    DB_NAME=$(echo "$SECRET_JSON" | grep -o '"dbname"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
fi

# Use values from infra_version.yaml if secret parsing failed
if [ -z "$DB_HOST" ] && [ -n "$RDS_ENDPOINT" ]; then
    DB_HOST="$RDS_ENDPOINT"
fi
if [ -z "$DB_PORT" ] && [ -n "$RDS_PORT" ]; then
    DB_PORT="$RDS_PORT"
fi
if [ -z "$DB_NAME" ] && [ -n "$RDS_DB_NAME" ]; then
    DB_NAME="$RDS_DB_NAME"
fi
if [ -z "$DB_USERNAME" ] && [ -n "$RDS_USERNAME" ]; then
    DB_USERNAME="$RDS_USERNAME"
fi

# Validate required values
if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ]; then
    echo "❌ Missing required database credentials:"
    echo "   DB_USERNAME: ${DB_USERNAME:-MISSING}"
    echo "   DB_PASSWORD: ${DB_PASSWORD:+SET}"
    echo "   DB_HOST: ${DB_HOST:-MISSING}"
    echo "   DB_PORT: ${DB_PORT:-MISSING}"
    echo "   DB_NAME: ${DB_NAME:-MISSING}"
    exit 1
fi

echo "✅ Retrieved credentials:"
echo "   Host: $DB_HOST"
echo "   Port: $DB_PORT"
echo "   Database: $DB_NAME"
echo "   Username: $DB_USERNAME"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

# Delete existing secret if it exists
if kubectl get secret db-credentials -n "$NAMESPACE" &> /dev/null; then
    echo "Deleting existing secret..."
    kubectl delete secret db-credentials -n "$NAMESPACE"
fi

# Create secret
echo "Creating db-credentials secret..."
kubectl create secret generic db-credentials \
  --from-literal=db-host="$DB_HOST" \
  --from-literal=db-port="$DB_PORT" \
  --from-literal=db-name="$DB_NAME" \
  --from-literal=db-username="$DB_USERNAME" \
  --from-literal=db-password="$DB_PASSWORD" \
  -n "$NAMESPACE"

echo ""
echo "✅ Secret 'db-credentials' created successfully in namespace '$NAMESPACE'"
echo ""
echo "Verify:"
echo "  kubectl get secret db-credentials -n $NAMESPACE"
echo "  kubectl describe secret db-credentials -n $NAMESPACE"

