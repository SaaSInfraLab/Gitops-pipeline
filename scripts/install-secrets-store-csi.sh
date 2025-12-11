#!/bin/bash
# Install AWS Secrets Store CSI Driver

set -e

echo "=========================================="
echo "Installing AWS Secrets Store CSI Driver"
echo "=========================================="
echo ""

# Install Secrets Store CSI Driver
echo "Installing Secrets Store CSI Driver..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/v1.4.0/deploy/secrets-store-csi-driver.yaml

# Wait for driver to be ready
echo "Waiting for Secrets Store CSI Driver to be ready..."
kubectl wait --for=condition=ready pod -l app=secrets-store-csi-driver -n kube-system --timeout=300s

# Install AWS Provider
echo "Installing AWS Provider for Secrets Store CSI Driver..."
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

# Wait for provider to be ready
echo "Waiting for AWS Provider to be ready..."
kubectl wait --for=condition=ready pod -l app=csi-secrets-store-provider-aws -n kube-system --timeout=300s

echo ""
echo "✅ AWS Secrets Store CSI Driver installed successfully"
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n kube-system | grep secrets-store"
echo "  kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io"

