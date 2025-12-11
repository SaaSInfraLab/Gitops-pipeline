#!/bin/bash
# Check ArgoCD Installation and Application Status

set -e

echo "=========================================="
echo "ArgoCD Diagnostic Check"
echo "=========================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot access Kubernetes cluster"
    echo "   Please configure kubectl: aws eks update-kubeconfig --name <cluster-name> --region <region>"
    exit 1
fi

echo "✅ Cluster connection OK"
echo ""

# Check if ArgoCD namespace exists
echo "📋 Checking ArgoCD namespace..."
if kubectl get namespace argocd &> /dev/null; then
    echo "✅ ArgoCD namespace exists"
else
    echo "❌ ArgoCD namespace not found"
    echo "   Install ArgoCD: cd argocd/bootstrap && ./install-argocd.sh"
    exit 1
fi

# Check ArgoCD pods
echo ""
echo "📋 Checking ArgoCD pods..."
ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$ARGOCD_PODS" -gt 0 ]; then
    echo "✅ Found $ARGOCD_PODS ArgoCD pod(s)"
    kubectl get pods -n argocd
else
    echo "❌ No ArgoCD pods found"
    echo "   Install ArgoCD: cd argocd/bootstrap && ./install-argocd.sh"
    exit 1
fi

# Check ArgoCD applications
echo ""
echo "📋 Checking ArgoCD applications..."
ARGOCD_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$ARGOCD_APPS" -gt 0 ]; then
    echo "✅ Found $ARGOCD_APPS ArgoCD application(s)"
    echo ""
    kubectl get applications -n argocd
    echo ""
    echo "📊 Application Details:"
    kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,STATUS:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL,REVISION:.spec.source.targetRevision
else
    echo "❌ No ArgoCD applications found"
    echo ""
    echo "   Create applications:"
    echo "   kubectl apply -f argocd/app-of-apps.yaml"
    echo ""
    echo "   Or individually:"
    echo "   kubectl apply -f argocd/applications/sample-saas-app-platform.yaml"
    echo "   kubectl apply -f argocd/applications/sample-saas-app-analytics.yaml"
    exit 1
fi

# Check specific application
echo ""
echo "📋 Checking sample-saas-app-platform application..."
if kubectl get application sample-saas-app-platform -n argocd &> /dev/null; then
    echo "✅ Application exists"
    echo ""
    echo "📊 Status:"
    kubectl get application sample-saas-app-platform -n argocd -o yaml | grep -A 10 "status:" || echo "   (No status available)"
    echo ""
    echo "📋 Sync Status:"
    kubectl describe application sample-saas-app-platform -n argocd | grep -A 5 "Status:" || echo "   (No sync status)"
else
    echo "❌ Application 'sample-saas-app-platform' not found"
    echo "   Create it: kubectl apply -f argocd/applications/sample-saas-app-platform.yaml"
fi

# Check repository access
echo ""
echo "📋 Checking repository access..."
if kubectl get application sample-saas-app-platform -n argocd &> /dev/null; then
    REPO_URL=$(kubectl get application sample-saas-app-platform -n argocd -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || echo "")
    if [ -n "$REPO_URL" ]; then
        echo "✅ Repository URL: $REPO_URL"
        echo "   (Check ArgoCD UI or logs for connection issues)"
    fi
fi

# Check ArgoCD server
echo ""
echo "📋 Checking ArgoCD server..."
if kubectl get svc argocd-server -n argocd &> /dev/null; then
    echo "✅ ArgoCD server service exists"
    echo ""
    echo "   Access ArgoCD UI:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   Then open: https://localhost:8080"
    echo ""
    echo "   Get admin password:"
    echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
else
    echo "❌ ArgoCD server service not found"
fi

echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="

