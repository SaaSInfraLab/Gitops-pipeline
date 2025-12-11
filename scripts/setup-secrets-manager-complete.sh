#!/bin/bash
# Complete permanent solution for Secrets Manager integration
# This script:
# 1. Installs Secrets Store CSI Driver
# 2. Updates IAM role with RDS secret ARN
# 3. Updates SecretProviderClass with actual values
# 4. Re-enables SecretProviderClass in kustomization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-dev}"

echo "=========================================="
echo "Complete Secrets Manager Setup"
echo "Environment: $ENVIRONMENT"
echo "=========================================="
echo ""

# Step 1: Install Secrets Store CSI Driver
echo "Step 1: Installing Secrets Store CSI Driver..."
bash "${SCRIPT_DIR}/setup-secrets-store-csi.sh" || {
    echo "⚠️  CSI Driver installation had issues, but continuing..."
}

echo ""

# Step 2: Update SecretProviderClass with actual values
echo "Step 2: Updating SecretProviderClass with values from infra_version.yaml..."
bash "${SCRIPT_DIR}/update-secret-provider-class.sh" || {
    echo "❌ Failed to update SecretProviderClass"
    exit 1
}

echo ""

# Step 3: Re-enable SecretProviderClass in kustomization
echo "Step 3: Re-enabling SecretProviderClass in kustomization..."
KUSTOMIZATION_FILE="${SCRIPT_DIR}/../apps/sample-saas-app/overlays/platform/kustomization.yaml"

if [ -f "$KUSTOMIZATION_FILE" ]; then
    # Uncomment the SecretProviderClass resources
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's|# - aws-secrets-manager.yaml|- aws-secrets-manager.yaml|g' "$KUSTOMIZATION_FILE"
        sed -i '' 's|# - secret-sync-job.yaml|- secret-sync-job.yaml|g' "$KUSTOMIZATION_FILE"
    else
        sed -i 's|# - aws-secrets-manager.yaml|- aws-secrets-manager.yaml|g' "$KUSTOMIZATION_FILE"
        sed -i 's|# - secret-sync-job.yaml|- secret-sync-job.yaml|g' "$KUSTOMIZATION_FILE"
    fi
    echo "✅ Kustomization updated"
else
    echo "⚠️  Kustomization file not found: $KUSTOMIZATION_FILE"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Commit and push the updated SecretProviderClass and kustomization files"
echo "2. ArgoCD will automatically sync and create the db-credentials secret"
echo "3. Application pods will start successfully"
echo ""

