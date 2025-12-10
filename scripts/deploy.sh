#!/bin/bash
# Deploy Infrastructure and Tenants
# This script clones the Terraform repo and deploys infrastructure using tfvars from infrastructure-config/

set -e

# Get environment from argument or default to dev
ENVIRONMENT="${1:-dev}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR=$(mktemp -d)
TERRAFORM_REPO_URL="https://github.com/SaaSInfraLab/cloudnative-saas-eks.git"

echo "=========================================="
echo "Deploying Infrastructure and Tenants"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI not found"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Error: git not found"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured"; exit 1; }
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

# Validate config directory exists (configs are in the cloned repo)
if [ ! -d "${CONFIG_DIR}" ]; then
    echo "Error: Configuration directory not found: ${CONFIG_DIR}"
    echo "Make sure config files exist in cloudnative-saas-eks/examples/dev-environment/config/"
    exit 1
fi

# Set paths - configs are now in the cloned cloudnative-saas-eks repo
CONFIG_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/config"
INFRA_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/infrastructure"
TENANTS_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/tenants"
COMMON_TFVARS="${CONFIG_DIR}/common.tfvars"
INFRA_TFVARS="${CONFIG_DIR}/infrastructure.tfvars"
TENANTS_TFVARS="${CONFIG_DIR}/tenants.tfvars"
INFRA_BACKEND="${CONFIG_DIR}/infrastructure/backend-dev.tfbackend"
TENANTS_BACKEND="${CONFIG_DIR}/tenants/backend-dev.tfbackend"

# Validate tfvars files exist
if [ ! -f "${COMMON_TFVARS}" ]; then
    echo "Error: Common tfvars not found: ${COMMON_TFVARS}"
    exit 1
fi

if [ ! -f "${INFRA_TFVARS}" ]; then
    echo "Error: Infrastructure tfvars not found: ${INFRA_TFVARS}"
    exit 1
fi

if [ ! -f "${TENANTS_TFVARS}" ]; then
    echo "Error: Tenants tfvars not found: ${TENANTS_TFVARS}"
    exit 1
fi

# Deploy Infrastructure
echo "=========================================="
echo "Step 1: Deploying Infrastructure"
echo "=========================================="
cd "${INFRA_DIR}"

echo "Initializing Terraform..."
terraform init -backend-config="${INFRA_BACKEND}"

echo "Applying infrastructure..."
terraform apply -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" --auto-approve

CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "")
if [ -z "$AWS_REGION" ]; then
    # Fallback: try to get from tfvars file
    AWS_REGION=$(grep -E "^aws_region\s*=" "${INFRA_TFVARS}" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1 || echo "us-east-1")
fi

if [ -n "$CLUSTER_NAME" ]; then
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" || true
fi

echo "✓ Infrastructure deployed"
echo ""

# Deploy Tenants
echo "=========================================="
echo "Step 2: Deploying Tenants"
echo "=========================================="
cd "${TENANTS_DIR}"

echo "Initializing Terraform..."
terraform init -backend-config="${TENANTS_BACKEND}"

echo "Applying tenants..."
terraform apply -var-file="${COMMON_TFVARS}" -var-file="${TENANTS_TFVARS}" --auto-approve

echo "✓ Tenants deployed"
echo ""

# Summary
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
if [ -n "$CLUSTER_NAME" ]; then
    echo "Cluster: $CLUSTER_NAME"
    echo "Region: $AWS_REGION"
    echo ""
    echo "Verify deployment:"
    echo "  kubectl get nodes"
    echo "  kubectl get namespaces"
fi

# Cleanup
echo ""
echo "Cleaning up temporary directory..."
rm -rf "${TEMP_DIR}"
echo "✓ Cleanup complete"

