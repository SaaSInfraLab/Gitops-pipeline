#!/bin/bash
# Uninstall Flux CD before migrating to Argo CD

set -e

echo "=========================================="
echo "Uninstalling Flux CD"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will remove all Flux CD components!"
echo "   Make sure you have:"
echo "   1. Installed Argo CD"
echo "   2. Created Argo CD Applications"
echo "   3. Verified applications are syncing"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborting..."
    exit 0
fi

# Check if flux CLI is available
if command -v flux &> /dev/null; then
    echo ""
    echo "Uninstalling Flux using flux CLI..."
    flux uninstall --silent || true
else
    echo ""
    echo "Flux CLI not found, removing components manually..."
    
    # Delete all Kustomizations
    echo "Deleting Kustomizations..."
    kubectl delete kustomizations --all -A --ignore-not-found=true || true
    
    # Delete all GitRepositories
    echo "Deleting GitRepositories..."
    kubectl delete gitrepositories --all -A --ignore-not-found=true || true
    
    # Delete Flux namespace
    echo "Deleting flux-system namespace..."
    kubectl delete namespace flux-system --ignore-not-found=true || true
fi

# Delete Flux CRDs
echo ""
echo "Deleting Flux CRDs..."
kubectl delete crd \
    kustomizations.kustomize.toolkit.fluxcd.io \
    gitrepositories.source.toolkit.fluxcd.io \
    helmreleases.helm.toolkit.fluxcd.io \
    helmrepositories.source.toolkit.fluxcd.io \
    imagerepositories.image.toolkit.fluxcd.io \
    imageupdateautomations.image.toolkit.fluxcd.io \
    imagepolicies.image.toolkit.fluxcd.io \
    ocirepositories.source.toolkit.fluxcd.io \
    buckets.source.toolkit.fluxcd.io \
    alerts.notification.toolkit.fluxcd.io \
    providers.notification.toolkit.fluxcd.io \
    receivers.notification.toolkit.fluxcd.io \
    --ignore-not-found=true || true

echo ""
echo "=========================================="
echo "Flux CD Uninstallation Complete!"
echo "=========================================="
echo ""
echo "Verify removal:"
echo "  kubectl get pods -n flux-system"
echo "  kubectl get crds | grep flux"
echo ""

