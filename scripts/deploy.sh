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
# Capture terraform output to check for errors
# Use tee to both capture and display output in real-time
terraform apply -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" --auto-approve 2>&1 | tee /tmp/terraform-apply-output.log
TF_EXIT_CODE=${PIPESTATUS[0]}
TF_OUTPUT=$(cat /tmp/terraform-apply-output.log)

# Check if error is for_each related
if [ $TF_EXIT_CODE -ne 0 ] && echo "$TF_OUTPUT" | grep -qiE "Invalid for_each|for_each.*will be known only after apply"; then
    echo ""
    echo "⚠️  for_each error detected. Applying dependencies first, then retrying..."
    echo "Error details:"
    echo "$TF_OUTPUT" | grep -iE "Invalid for_each|for_each" | head -3
    
    # Try to apply base resources first (VPC, Security Groups, EKS Cluster)
    # This creates the resources that for_each depends on
    echo ""
    echo "=========================================="
    echo "Step 1: Applying Base Resources First"
    echo "=========================================="
    echo "Applying VPC and Security Groups first..."
    terraform apply -target=module.vpc \
      -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" --auto-approve 2>&1 | tee /tmp/terraform-apply-stage1.log || {
      echo "⚠️  Stage 1 apply had issues, but continuing..."
    }
    
    echo ""
    echo "Applying EKS Cluster..."
    terraform apply -target=module.eks.module.eks.aws_eks_cluster.main \
      -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" --auto-approve 2>&1 | tee /tmp/terraform-apply-stage2.log || {
      echo "⚠️  Stage 2 apply had issues, but continuing..."
    }
    
    # Now retry full apply (for_each should work now that dependencies exist)
    echo ""
    echo "=========================================="
    echo "Step 2: Retrying Full Infrastructure Apply"
    echo "=========================================="
    echo "Now that base resources exist, retrying full apply..."
    terraform apply -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" --auto-approve 2>&1 | tee /tmp/terraform-apply-output.log
    TF_EXIT_CODE=${PIPESTATUS[0]}
    TF_OUTPUT=$(cat /tmp/terraform-apply-output.log)
fi

# Check if error is duplicate security group rule
if [ $TF_EXIT_CODE -ne 0 ] && echo "$TF_OUTPUT" | grep -qiE "InvalidPermission\.Duplicate|duplicate.*Security Group rule|already exists"; then
    echo ""
    echo "⚠️  Duplicate security group rule detected. Fixing automatically..."
    echo "Error details:"
    echo "$TF_OUTPUT" | grep -iE "InvalidPermission|duplicate|already exists" | head -5
    
    # Run cleanup script to remove orphaned rules
    if [ -f "${SCRIPT_DIR}/fix-rds-security-group-rules.sh" ]; then
        echo "Running fix script..."
        bash "${SCRIPT_DIR}/fix-rds-security-group-rules.sh" "${TEMP_DIR}" "${INFRA_DIR}" || {
            echo "⚠️  Fix script encountered an issue, but continuing with retry..."
        }
    else
        echo "⚠️  Fix script not found at ${SCRIPT_DIR}/fix-rds-security-group-rules.sh"
    fi
    
    echo ""
    echo "Retrying terraform apply..."
    terraform apply -var-file="${COMMON_TFVARS}" -var-file="${INFRA_TFVARS}" --auto-approve
elif [ $TF_EXIT_CODE -ne 0 ]; then
    # Different error - show full output and exit
    echo ""
    echo "❌ Terraform apply failed with exit code: $TF_EXIT_CODE"
    echo "=========================================="
    echo "Full Terraform Output:"
    echo "=========================================="
    echo "$TF_OUTPUT"
    echo "=========================================="
    exit $TF_EXIT_CODE
else
    # Success - show output
    echo "$TF_OUTPUT"
fi

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

