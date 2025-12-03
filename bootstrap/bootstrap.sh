#!/bin/bash
# Simple Flux CD Bootstrap Script

set -e

echo "=========================================="
echo "Flux CD Bootstrap"
echo "=========================================="
echo ""

# Configuration
GITHUB_OWNER="${GITHUB_OWNER:-SaaSInfraLab}"
GITHUB_REPO="${GITHUB_REPO:-flux-gitops-pipeline}"
GITHUB_BRANCH="${GITHUB_BRANCH:-develop}"
CLUSTER_PATH="${CLUSTER_PATH:-clusters/dev-environment}"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot access Kubernetes cluster"
    echo "   Run: aws eks update-kubeconfig --name <cluster-name> --region <region>"
    exit 1
fi

if ! command -v flux &> /dev/null; then
    echo "❌ Error: flux CLI not found"
    echo ""
    echo "Install Flux CLI:"
    echo "  Windows: choco install flux (or download from GitHub)"
    echo "  Linux/Mac: curl -s https://fluxcd.io/install.sh | sudo bash"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Get GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "GitHub authentication:"
    echo "  1. Use token (recommended)"
    echo "  2. Use SSH (press Enter)"
    echo ""
    read -p "Enter GitHub token (or press Enter for SSH): " GITHUB_TOKEN
fi

# Bootstrap
echo ""
echo "Bootstrapping Flux CD..."
echo "  Repository: $GITHUB_OWNER/$GITHUB_REPO"
echo "  Branch: $GITHUB_BRANCH"
echo "  Path: $CLUSTER_PATH"
echo ""

if [ -n "$GITHUB_TOKEN" ]; then
    flux bootstrap github \
        --owner="$GITHUB_OWNER" \
        --repository="$GITHUB_REPO" \
        --branch="$GITHUB_BRANCH" \
        --path="$CLUSTER_PATH" \
        --token-auth \
        --personal
else
    flux bootstrap github \
        --owner="$GITHUB_OWNER" \
        --repository="$GITHUB_REPO" \
        --branch="$GITHUB_BRANCH" \
        --path="$CLUSTER_PATH" \
        --ssh-key-algorithm=ecdsa \
        --ssh-ecdsa-curve=p384
fi

# Wait for pods
echo ""
echo "Waiting for Flux components to be ready..."
kubectl wait --for=condition=ready pod --all -n flux-system --timeout=300s

# Verify
echo ""
echo "=========================================="
echo "Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n flux-system"
echo "  flux get sources git"
echo "  flux get kustomizations"
echo ""

