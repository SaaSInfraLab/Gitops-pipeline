#!/bin/bash
# Install Flux CD Components First
# Run this before bootstrap if you get CRD errors

set -e

echo "=========================================="
echo "Installing Flux CD Components"
echo "=========================================="
echo ""

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot access Kubernetes cluster"
    exit 1
fi

if ! command -v flux &> /dev/null; then
    echo "❌ Error: flux CLI not found"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Install Flux components
echo "Installing Flux CD components..."
flux install

echo ""
echo "Waiting for components to be ready..."
kubectl wait --for=condition=ready pod --all -n flux-system --timeout=300s

echo ""
echo "=========================================="
echo "Flux Components Installed!"
echo "=========================================="
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n flux-system"
echo "  kubectl get crds | grep flux"
echo ""
echo "Now you can run bootstrap:"
echo "  flux bootstrap github \\"
echo "    --owner=SaaSInfraLab \\"
echo "    --repository=flux-gitops-pipeline \\"
echo "    --branch=develop \\"
echo "    --path=clusters/dev-environment \\"
echo "    --token-auth \\"
echo "    --personal"
echo ""

