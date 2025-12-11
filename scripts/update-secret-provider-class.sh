#!/bin/bash
# Update SecretProviderClass with actual values from infra_version.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_VERSION_FILE="${SCRIPT_DIR}/../infra_version.yaml"
SECRET_PROVIDER_FILE="${SCRIPT_DIR}/../apps/sample-saas-app/overlays/platform/aws-secrets-manager.yaml"

if [ ! -f "$INFRA_VERSION_FILE" ]; then
    echo "❌ Error: infra_version.yaml not found at $INFRA_VERSION_FILE"
    exit 1
fi

if [ ! -f "$SECRET_PROVIDER_FILE" ]; then
    echo "❌ Error: aws-secrets-manager.yaml not found at $SECRET_PROVIDER_FILE"
    exit 1
fi

echo "Updating SecretProviderClass with values from infra_version.yaml..."

# Extract values from infra_version.yaml
RDS_SECRET_ARN=$(grep "rds_secret_arn:" "$INFRA_VERSION_FILE" | awk '{print $2}' | tr -d '"')
AWS_ACCOUNT_ID=$(grep "aws_account_id:" "$INFRA_VERSION_FILE" | awk '{print $2}' | tr -d '"')

# Get Secrets Manager role ARN (if it exists in outputs)
SECRETS_MANAGER_ROLE_ARN=$(grep "secrets_manager_role_arn:" "$INFRA_VERSION_FILE" | awk '{print $2}' | tr -d '"' || echo "")

if [ -z "$RDS_SECRET_ARN" ]; then
    echo "❌ Error: Could not find rds_secret_arn in infra_version.yaml"
    exit 1
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Error: Could not find aws_account_id in infra_version.yaml"
    exit 1
fi

# If Secrets Manager role doesn't exist, use a default name pattern
if [ -z "$SECRETS_MANAGER_ROLE_ARN" ]; then
    CLUSTER_NAME=$(grep "cluster_name:" "$INFRA_VERSION_FILE" | awk '{print $2}' | tr -d '"')
    PROJECT_NAME=$(echo "$CLUSTER_NAME" | cut -d'-' -f1-3)
    SECRETS_MANAGER_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-secrets-manager-role"
    echo "⚠️  Secrets Manager role ARN not found, using default: $SECRETS_MANAGER_ROLE_ARN"
fi

echo "RDS Secret ARN: $RDS_SECRET_ARN"
echo "Secrets Manager Role ARN: $SECRETS_MANAGER_ROLE_ARN"
echo ""

# Update the SecretProviderClass file
# Replace ${RDS_SECRET_ARN} with actual ARN
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|\${RDS_SECRET_ARN}|${RDS_SECRET_ARN}|g" "$SECRET_PROVIDER_FILE"
    sed -i '' "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|g" "$SECRET_PROVIDER_FILE"
    # Update role ARN in ServiceAccount annotation
    sed -i '' "s|arn:aws:iam::\${AWS_ACCOUNT_ID}:role/EKSSecretsManagerRole|${SECRETS_MANAGER_ROLE_ARN}|g" "$SECRET_PROVIDER_FILE"
else
    # Linux
    sed -i "s|\${RDS_SECRET_ARN}|${RDS_SECRET_ARN}|g" "$SECRET_PROVIDER_FILE"
    sed -i "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|g" "$SECRET_PROVIDER_FILE"
    sed -i "s|arn:aws:iam::\${AWS_ACCOUNT_ID}:role/EKSSecretsManagerRole|${SECRETS_MANAGER_ROLE_ARN}|g" "$SECRET_PROVIDER_FILE"
fi

echo "✅ SecretProviderClass updated successfully"
echo ""

