#!/bin/bash
# One-time cleanup script to fix deployment selector mismatches
# This script deletes existing deployments with incorrect selectors
# ArgoCD will automatically recreate them with the correct selectors from Git

set -e

echo "=========================================="
echo "Fixing Deployment Selector Mismatches"
echo "=========================================="
echo ""
echo "This script will delete deployments with incorrect selectors."
echo "ArgoCD will automatically recreate them with correct selectors."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot access Kubernetes cluster"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Function to delete deployment if it exists
delete_deployment() {
    local namespace=$1
    local deployment=$2
    
    if kubectl get deployment "$deployment" -n "$namespace" &>/dev/null; then
        echo "Deleting deployment $deployment in namespace $namespace..."
        kubectl delete deployment "$deployment" -n "$namespace" --wait=false
        echo "✅ Deleted $deployment"
    else
        echo "ℹ️  Deployment $deployment not found in $namespace, skipping"
    fi
}

# Function to delete job if it exists
delete_job() {
    local namespace=$1
    local job=$2
    
    if kubectl get job "$job" -n "$namespace" &>/dev/null; then
        echo "Deleting job $job in namespace $namespace..."
        kubectl delete job "$job" -n "$namespace" --wait=false
        echo "✅ Deleted $job"
    else
        echo "ℹ️  Job $job not found in $namespace, skipping"
    fi
}

# Fix analytics namespace
echo "Fixing analytics namespace..."
delete_deployment "analytics" "backend"
delete_deployment "analytics" "frontend"
delete_job "analytics" "init-rds-database"
echo ""

# Fix platform namespace
echo "Fixing platform namespace..."
delete_deployment "platform" "backend"
delete_deployment "platform" "frontend"
echo ""

echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "ArgoCD will automatically recreate these deployments with correct selectors."
echo "Check ArgoCD sync status:"
echo "  kubectl get applications -n argocd"
echo ""

