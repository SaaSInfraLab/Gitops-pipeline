#!/bin/bash
# Install ArgoCD and create applications after infrastructure deployment

set -e

ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="${2:-/tmp}"

echo "=========================================="
echo "Installing ArgoCD"
echo "Environment: $ENVIRONMENT"
echo "=========================================="
echo ""

# Get cluster info - try multiple methods
CONFIG_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/config"
INFRA_DIR="${TEMP_DIR}/cloudnative-saas-eks/examples/dev-environment/infrastructure"

CLUSTER_NAME=""
AWS_REGION="${AWS_REGION:-us-east-1}"

# Method 1: Try to get from Terraform outputs (if repo is cloned and initialized)
if [ -d "$INFRA_DIR" ] && [ -f "$INFRA_DIR/main.tf" ]; then
    cd "$INFRA_DIR"
    
    # Try to initialize Terraform if backend config exists
    BACKEND_CONFIG="${CONFIG_DIR}/infrastructure/backend-${ENVIRONMENT}.tfbackend"
    if [ -f "$BACKEND_CONFIG" ] && [ ! -d ".terraform" ]; then
        echo "Initializing Terraform to read outputs..."
        terraform init -backend-config="$BACKEND_CONFIG" -backend=false 2>/dev/null || true
    fi
    
    # Try to read outputs
    if [ -d ".terraform" ] || [ -f ".terraform.lock.hcl" ]; then
        CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
        AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "$AWS_REGION")
        
        if [ -n "$CLUSTER_NAME" ]; then
            echo "✅ Got cluster info from Terraform outputs"
        fi
    fi
fi

# Method 2: Try to get from AWS (list EKS clusters)
if [ -z "$CLUSTER_NAME" ]; then
    echo "⚠️  Could not get cluster name from Terraform, trying AWS..."
    # List all EKS clusters and use the first one (or filter by name pattern)
    CLUSTER_NAME=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters[0]' --output text 2>/dev/null || echo "")
    
    if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" == "None" ]; then
        echo "❌ Could not determine cluster name"
        echo "   Please ensure:"
        echo "   1. The EKS cluster exists in region $AWS_REGION"
        echo "   2. AWS credentials are configured"
        echo "   3. You have permissions to list EKS clusters"
        exit 1
    fi
    echo "✅ Found cluster via AWS: $CLUSTER_NAME"
fi

if [ -z "$CLUSTER_NAME" ]; then
    echo "❌ Could not determine cluster name"
    exit 1
fi

echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" || {
    echo "❌ Failed to configure kubectl"
    exit 1
}

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot access Kubernetes cluster"
    exit 1
fi

echo "✅ Cluster connection OK"
echo ""

# Check if ArgoCD is already installed
if kubectl get namespace argocd &> /dev/null; then
    echo "ℹ️  ArgoCD namespace already exists"
    ARGOCD_INSTALLED=true
else
    ARGOCD_INSTALLED=false
fi

# Install ArgoCD if not installed
if [ "$ARGOCD_INSTALLED" = false ]; then
    echo "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || {
        echo "❌ Failed to install ArgoCD"
        exit 1
    }
    
    # Wait for ArgoCD to be ready (with timeout)
    echo "Waiting for ArgoCD components to be ready..."
    kubectl wait --for=condition=ready pod --all -n argocd --timeout=600s || {
        echo "⚠️  ArgoCD pods not ready within timeout, but continuing..."
    }
    
    echo "✅ ArgoCD installed"
else
    echo "✅ ArgoCD already installed"
fi

echo ""

# Wait a bit for ArgoCD to be fully ready
echo "Waiting for ArgoCD server to be ready..."
sleep 10

# Check if applications already exist
cd "$SCRIPT_DIR/.."
ARGOCD_APPS_DIR="argocd/applications"

if [ ! -d "$ARGOCD_APPS_DIR" ]; then
    echo "⚠️  ArgoCD applications directory not found: $ARGOCD_APPS_DIR"
    echo "   Skipping application creation"
    exit 0
fi

# Create applications
echo "Creating ArgoCD applications..."

# Check if app-of-apps exists
if [ -f "argocd/app-of-apps.yaml" ]; then
    echo "Applying App of Apps pattern..."
    kubectl apply -f argocd/app-of-apps.yaml || {
        echo "⚠️  Failed to apply app-of-apps, trying individual applications..."
        
        # Fallback: apply individual applications
        for app_file in "$ARGOCD_APPS_DIR"/*.yaml; do
            if [ -f "$app_file" ]; then
                echo "  Applying $(basename "$app_file")..."
                kubectl apply -f "$app_file" || echo "    ⚠️  Failed to apply $app_file"
            fi
        done
    }
else
    # Apply individual applications
    echo "Applying individual applications..."
    for app_file in "$ARGOCD_APPS_DIR"/*.yaml; do
        if [ -f "$app_file" ]; then
            echo "  Applying $(basename "$app_file")..."
            kubectl apply -f "$app_file" || echo "    ⚠️  Failed to apply $app_file"
        fi
    done
fi

echo ""
echo "✅ ArgoCD applications created"
echo ""

# Show application status
echo "ArgoCD Application Status:"
kubectl get applications -n argocd 2>/dev/null || echo "  (Applications may still be initializing)"

echo ""
echo "=========================================="
echo "ArgoCD Installation Complete!"
echo "=========================================="
echo ""
echo "To access ArgoCD UI:"
echo "  1. Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open: https://localhost:8080"
echo "  3. Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""

