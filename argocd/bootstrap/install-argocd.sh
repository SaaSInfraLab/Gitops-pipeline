#!/bin/bash
# Install Argo CD on Kubernetes Cluster

set -e

echo "=========================================="
echo "Installing Argo CD"
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

echo "✅ Prerequisites OK"
echo ""

# Create namespace
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
echo "Installing Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
echo ""
echo "Waiting for Argo CD components to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=600s

# Get admin password
echo ""
echo "=========================================="
echo "Argo CD Installation Complete!"
echo "=========================================="
echo ""
echo "Argo CD Admin Credentials:"
echo "  Username: admin"
echo "  Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo ""
echo ""
echo "Access Argo CD UI:"
echo "  1. Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open: https://localhost:8080"
echo "  3. Login with credentials above"
echo ""
echo "Or use Argo CD CLI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  argocd login localhost:8080"
echo ""

