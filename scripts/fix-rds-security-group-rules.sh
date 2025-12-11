#!/bin/bash
# Fix duplicate RDS security group rules
# This script removes orphaned security group rules that exist in AWS but not in Terraform state
# Called automatically when duplicate rule errors are detected

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="${1:-/tmp}"

# Get infrastructure directory from environment or use current directory
INFRA_DIR="${2:-$(pwd)}"

echo "Fixing RDS Security Group Rules..."
echo ""

# Change to infrastructure directory if provided
if [ -n "$2" ] && [ -d "$2" ]; then
    cd "$2"
fi

# Check if we're in the infrastructure directory
if [ ! -f "main.tf" ] || [ ! -d ".terraform" ]; then
    echo "⚠️  Not in Terraform infrastructure directory. Skipping rule cleanup."
    exit 0
fi

# Get RDS security group ID from Terraform state
RDS_SG_ID=$(terraform output -raw module.rds.security_group_id 2>/dev/null || echo "")

if [ -z "$RDS_SG_ID" ]; then
    echo "⚠️  RDS security group not found in state. Skipping rule cleanup."
    exit 0
fi

# Get existing ingress rules for port 5432 (PostgreSQL) that reference other security groups
EXISTING_RULES=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=$RDS_SG_ID" \
    --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==5432 && ToPort==5432 && IsEgress==\`false\` && ReferencedGroupInfo!=null].SecurityGroupRuleId" \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_RULES" ]; then
    echo "✓ No existing rules found. Nothing to clean up."
    exit 0
fi

# Remove all existing rules for port 5432 from security groups
# Terraform will recreate them properly
echo "Removing existing rules to allow Terraform to recreate them..."
for RULE_ID in $EXISTING_RULES; do
    aws ec2 revoke-security-group-ingress \
        --group-id "$RDS_SG_ID" \
        --security-group-rule-ids "$RULE_ID" \
        --output text >/dev/null 2>&1 || true
done

RULE_COUNT=$(echo $EXISTING_RULES | wc -w)
echo "✓ Removed $RULE_COUNT rule(s). Terraform will recreate them."

