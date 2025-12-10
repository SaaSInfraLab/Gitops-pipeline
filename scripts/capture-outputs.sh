#!/bin/bash
# Capture Terraform Outputs and Write to infra_version.yaml
# This script extracts outputs from both infrastructure and tenants Terraform states
# and writes them to infra_version.yaml in the repo root

set -e

# Get environment from argument or default to dev
ENVIRONMENT="${1:-dev}"

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_FILE="${REPO_ROOT}/infra_version.yaml"
TEMP_DIR=$(mktemp -d)
TERRAFORM_REPO_URL="https://github.com/SaaSInfraLab/cloudnative-saas-eks.git"

echo "=========================================="
echo "Capturing Terraform Outputs"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Clone Terraform repo (contains both code and configs)
echo "Cloning Terraform repository..."
git clone --depth 1 "${TERRAFORM_REPO_URL}" "${TEMP_DIR}/cloudnative-saas-eks" >/dev/null 2>&1 || {
    echo "Error: Failed to clone Terraform repository"
    exit 1
}

# Set paths - configs are now in the cloned cloudnative-saas-eks repo
CONFIG_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/config"
INFRA_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/infrastructure"
TENANTS_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/tenants"
INFRA_BACKEND="${CONFIG_DIR}/infrastructure/backend-dev.tfbackend"
TENANTS_BACKEND="${CONFIG_DIR}/tenants/backend-dev.tfbackend"

# Initialize and get infrastructure outputs
echo "Extracting infrastructure outputs..."
cd "${INFRA_DIR}"
terraform init -backend-config="${INFRA_BACKEND}" >/dev/null 2>&1
INFRA_OUTPUTS=$(terraform output -json 2>/dev/null || echo "{}")

# Initialize and get tenants outputs
echo "Extracting tenants outputs..."
cd "${TENANTS_DIR}"
terraform init -backend-config="${TENANTS_BACKEND}" >/dev/null 2>&1
TENANTS_OUTPUTS=$(terraform output -json 2>/dev/null || echo "{}")

# Get key values from infrastructure outputs
CLUSTER_NAME=$(echo "${INFRA_OUTPUTS}" | grep -o '"cluster_name"[^}]*' | grep -o '"[^"]*"' | head -1 | tr -d '"' || echo "")
AWS_REGION=$(echo "${INFRA_OUTPUTS}" | grep -o '"aws_region"[^}]*' | grep -o '"[^"]*"' | head -1 | tr -d '"' || echo "")
if [ -z "$AWS_REGION" ]; then
    # Fallback: try to get from tfvars file
    AWS_REGION=$(grep -E "^aws_region\s*=" "${CONFIG_DIR}/infrastructure.tfvars" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1 || echo "us-east-1")
fi

# Generate version (use timestamp-based version or increment from existing)
if [ -f "${OUTPUT_FILE}" ]; then
    CURRENT_VERSION=$(grep "^version:" "${OUTPUT_FILE}" | awk '{print $2}' | tr -d '"' || echo "1.0.0")
    # Simple version bump - increment patch version
    MAJOR=$(echo "${CURRENT_VERSION}" | cut -d. -f1)
    MINOR=$(echo "${CURRENT_VERSION}" | cut -d. -f2)
    PATCH=$(echo "${CURRENT_VERSION}" | cut -d. -f3)
    PATCH=$((PATCH + 1))
    VERSION="${MAJOR}.${MINOR}.${PATCH}"
else
    VERSION="1.0.0"
fi

# Get current timestamp in ISO format
LAST_DEPLOYED=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "")

# Create YAML file
echo "Writing outputs to ${OUTPUT_FILE}..."
cat > "${OUTPUT_FILE}" <<EOF
version: "${VERSION}"
last_deployed: "${LAST_DEPLOYED}"
cluster_name: "${CLUSTER_NAME}"
aws_region: "${AWS_REGION}"
terraform_outputs:
  infrastructure:
EOF

# Convert JSON outputs to YAML format (simplified approach)
# For complex nested structures, we'll use a simple key-value format
echo "${INFRA_OUTPUTS}" | python3 -c "
import json
import sys
import yaml

try:
    data = json.load(sys.stdin)
    # Convert to simple key-value pairs for YAML
    outputs = {}
    for key, value in data.items():
        if isinstance(value, dict) and 'value' in value:
            val = value['value']
            # Handle different types
            if isinstance(val, (str, int, float, bool)):
                outputs[key] = val
            elif isinstance(val, list):
                outputs[key] = val
            elif isinstance(val, dict):
                outputs[key] = val
            else:
                outputs[key] = str(val)
        else:
            outputs[key] = value
    
    # Print as YAML with proper indentation
    for key, value in outputs.items():
        if isinstance(value, str) and not value.startswith('[') and not value.startswith('{'):
            print(f'    {key}: \"{value}\"')
        else:
            print(f'    {key}: {value}')
except Exception as e:
    # Fallback: just print raw JSON keys
    data = json.load(sys.stdin)
    for key in data.keys():
        print(f'    {key}: \"<output_value>\"')
" 2>/dev/null >> "${OUTPUT_FILE}" || {
    # Fallback if Python is not available
    echo "    # Outputs extracted from Terraform state" >> "${OUTPUT_FILE}"
    echo "    # Note: Install Python3 with PyYAML for full output extraction" >> "${OUTPUT_FILE}"
}

cat >> "${OUTPUT_FILE}" <<EOF
  tenants:
EOF

# Add tenants outputs
echo "${TENANTS_OUTPUTS}" | python3 -c "
import json
import sys
import yaml

try:
    data = json.load(sys.stdin)
    outputs = {}
    for key, value in data.items():
        if isinstance(value, dict) and 'value' in value:
            val = value['value']
            if isinstance(val, (str, int, float, bool)):
                outputs[key] = val
            elif isinstance(val, list):
                outputs[key] = val
            elif isinstance(val, dict):
                outputs[key] = val
            else:
                outputs[key] = str(val)
        else:
            outputs[key] = value
    
    for key, value in outputs.items():
        if isinstance(value, str) and not value.startswith('[') and not value.startswith('{'):
            print(f'    {key}: \"{value}\"')
        else:
            print(f'    {key}: {value}')
except Exception as e:
    data = json.load(sys.stdin)
    for key in data.keys():
        print(f'    {key}: \"<output_value>\"')
" 2>/dev/null >> "${OUTPUT_FILE}" || {
    echo "    # Outputs extracted from Terraform state" >> "${OUTPUT_FILE}"
    echo "    # Note: Install Python3 with PyYAML for full output extraction" >> "${OUTPUT_FILE}"
}

echo "✓ Outputs captured to ${OUTPUT_FILE}"
echo ""

# Cleanup
rm -rf "${TEMP_DIR}"

# Display summary
echo "Summary:"
echo "  Version: ${VERSION}"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  Output file: ${OUTPUT_FILE}"

