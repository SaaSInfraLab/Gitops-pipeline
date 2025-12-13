#!/bin/bash
# Destroy Infrastructure and Tenants
# This script clones the Terraform repo and destroys infrastructure
# Supports non-interactive mode via AUTO_APPROVE environment variable

set -e

# Get environment from argument or default to dev
ENVIRONMENT="${1:-dev}"

# Check for non-interactive mode
AUTO_APPROVE="${AUTO_APPROVE:-false}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR=$(mktemp -d)
TERRAFORM_REPO_URL="https://github.com/SaaSInfraLab/cloudnative-saas-eks.git"

echo "=========================================="
echo "Destroying Infrastructure and Tenants"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Confirmation (skip if AUTO_APPROVE is set)
if [ "${AUTO_APPROVE}" != "true" ]; then
    echo "WARNING: This will destroy all resources!"
    read -p "Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled"
        exit 0
    fi
    echo ""
fi

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI not found"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Error: git not found"; exit 1; }
echo "✓ Prerequisites OK"
echo ""

# Clone Terraform repo (contains both code and configs)
echo "=========================================="
echo "Cloning Terraform Repository"
echo "=========================================="
echo "Cloning ${TERRAFORM_REPO_URL} to ${TEMP_DIR}/cloudnative-saas-eks..."
git clone --depth 1 "${TERRAFORM_REPO_URL}" "${TEMP_DIR}/cloudnative-saas-eks" || {
    echo "Error: Failed to clone Terraform repository"
    exit 1
}
echo "✓ Repository cloned"
echo ""

# Set paths - configs are now in the cloned cloudnative-saas-eks repo
CONFIG_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/config"
INFRA_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/infrastructure"
TENANTS_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/tenants"
COMMON_TFVARS="${CONFIG_DIR}/common.tfvars"
INFRA_TFVARS="${CONFIG_DIR}/infrastructure.tfvars"
TENANTS_TFVARS="${CONFIG_DIR}/tenants.tfvars"
INFRA_BACKEND="${CONFIG_DIR}/infrastructure/backend-dev.tfbackend"
TENANTS_BACKEND="${CONFIG_DIR}/tenants/backend-dev.tfbackend"

# Validate config directory exists (configs are in the cloned repo)
if [ ! -d "${CONFIG_DIR}" ]; then
    echo "Error: Configuration directory not found: ${CONFIG_DIR}"
    echo "Make sure config files exist in cloudnative-saas-eks/examples/dev-environment/config/"
    exit 1
fi

# Destroy Tenants (must be destroyed before infrastructure)
echo "=========================================="
echo "Step 1: Destroying Tenants"
echo "=========================================="
cd "${TENANTS_DIR}"

if [ -f "${TENANTS_BACKEND}" ]; then
    echo "Initializing Terraform for tenants..."
    terraform init -backend-config="${TENANTS_BACKEND}" -reconfigure
    
    if [ "${AUTO_APPROVE}" = "true" ]; then
        echo "Destroying tenants (auto-approve with -refresh=false)..."
        terraform destroy -refresh=false -var-file="${COMMON_TFVARS}" -var-file="${TENANTS_TFVARS}" -auto-approve || echo "No tenant resources to destroy"
    else
        echo "Destroying tenants (with -refresh=false)..."
        terraform destroy -refresh=false -var-file="${COMMON_TFVARS}" -var-file="${TENANTS_TFVARS}" || echo "No tenant resources to destroy"
    fi
else
    echo "Backend config not found, skipping tenants"
fi

echo "✓ Tenants destroyed"
echo ""

# Destroy Infrastructure
echo "=========================================="
echo "Step 2: Destroying Infrastructure"
echo "=========================================="
cd "${INFRA_DIR}"

if [ -f "${INFRA_BACKEND}" ]; then
    echo "Initializing Terraform for infrastructure..."
    terraform init -backend-config="${INFRA_BACKEND}" -reconfigure
    
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "")
    if [ -z "$AWS_REGION" ]; then
        # Fallback: try to get from tfvars file
        AWS_REGION=$(grep -E "^aws_region\s*=" "${INFRA_TFVARS}" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1 || echo "us-east-1")
    fi
    
    if [ "${AUTO_APPROVE}" = "true" ]; then
        echo "Destroying infrastructure (auto-approve with -refresh=false)..."
        terraform destroy -refresh=false -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" -auto-approve
    else
        echo "Destroying infrastructure (with -refresh=false)..."
        terraform destroy -refresh=false -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}"
    fi
    
    # Clean up kubeconfig
    if [ -n "$CLUSTER_NAME" ] && command -v kubectl >/dev/null 2>&1; then
        kubectl config delete-cluster "arn:aws:eks:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${CLUSTER_NAME}" 2>/dev/null || true
        kubectl config delete-context "${CLUSTER_NAME}" 2>/dev/null || true
    fi
else
    echo "Backend config not found, skipping infrastructure"
fi

echo "✓ Infrastructure destroyed"
echo ""

echo "=========================================="
echo "Destruction Complete!"
echo "=========================================="

# Cleanup
echo ""
echo "Cleaning up temporary directory..."
rm -rf "${TEMP_DIR}"
echo "✓ Cleanup complete"

