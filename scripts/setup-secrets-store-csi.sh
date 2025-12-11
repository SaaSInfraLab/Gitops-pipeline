#!/bin/bash
# Complete setup for AWS Secrets Store CSI Driver - Permanent Solution

set -e

echo "=========================================="
echo "Setting up AWS Secrets Store CSI Driver"
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

# Step 1: Install Secrets Store CSI Driver
echo "Step 1: Installing Secrets Store CSI Driver..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/v1.4.0/deploy/secrets-store-csi-driver.yaml

# Wait for CRDs to be ready
echo "Waiting for CRDs to be ready..."
kubectl wait --for condition=established --timeout=60s crd/secretproviderclasses.secrets-store.csi.x-k8s.io 2>/dev/null || {
    echo "⚠️  CRD not ready yet, continuing..."
}

# Wait for driver pods
echo "Waiting for Secrets Store CSI Driver pods to be ready..."
kubectl wait --for=condition=ready pod -l app=secrets-store-csi-driver -n kube-system --timeout=300s || {
    echo "⚠️  Driver pods not ready within timeout, but continuing..."
}

echo "✅ Secrets Store CSI Driver installed"
echo ""

# Step 2: Install AWS Provider
echo "Step 2: Installing AWS Provider for Secrets Store CSI Driver..."
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

# Wait for provider pods
echo "Waiting for AWS Provider pods to be ready..."
kubectl wait --for=condition=ready pod -l app=csi-secrets-store-provider-aws -n kube-system --timeout=300s || {
    echo "⚠️  Provider pods not ready within timeout, but continuing..."
}

echo "✅ AWS Provider installed"
echo ""

# Step 3: Verify installation
echo "Step 3: Verifying installation..."
echo ""

echo "CSI Driver DaemonSet:"
kubectl get daemonset csi-secrets-store -n kube-system || echo "  ⚠️  Not found"

echo ""
echo "AWS Provider DaemonSet:"
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system || echo "  ⚠️  Not found"

echo ""
echo "CRD:"
kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io || echo "  ⚠️  Not found"

echo ""
echo "Pods:"
kubectl get pods -n kube-system | grep secrets-store || echo "  ⚠️  No pods found"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Ensure IAM role for Secrets Manager is created (via Terraform)"
echo "2. Update SecretProviderClass with correct IAM role ARN and secret ARN"
echo "3. ArgoCD will automatically sync and create the secret"
echo ""

