#!/bin/bash
# Get Application URLs from LoadBalancer Services

set -e

echo "=========================================="
echo "Application URLs"
echo "=========================================="
echo ""

# Function to get URL for a namespace
get_url() {
    local namespace=$1
    local tenant_name=$2
    
    echo "📱 $tenant_name Tenant:"
    
    if kubectl get svc frontend-service -n "$namespace" &>/dev/null; then
        local url=$(kubectl get svc frontend-service -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$url" ] && [ "$url" != "<none>" ]; then
            echo "   🌐 Frontend URL: http://$url"
            echo "   🔗 Backend API: http://$url/api (via frontend proxy)"
        else
            echo "   ⏳ LoadBalancer is still provisioning..."
            echo "   Run: kubectl get svc frontend-service -n $namespace"
        fi
    else
        echo "   ❌ Frontend service not found in $namespace namespace"
    fi
    
    echo ""
}

# Get URLs for each tenant
get_url "analytics" "Analytics"
get_url "platform" "Platform"

echo "=========================================="
echo "Additional Information"
echo "=========================================="
echo ""
echo "📋 View all services:"
echo "   kubectl get svc -A | grep frontend-service"
echo ""
echo "🔍 Check service details:"
echo "   kubectl describe svc frontend-service -n analytics"
echo "   kubectl describe svc frontend-service -n platform"
echo ""
echo "📊 Check pod status:"
echo "   kubectl get pods -n analytics"
echo "   kubectl get pods -n platform"
echo ""

