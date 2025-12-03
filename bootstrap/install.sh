#!/bin/bash

# Flux CD Bootstrap Installation Script
# This script installs Flux CLI and bootstraps Flux CD on an EKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
FLUX_VERSION="${FLUX_VERSION:-2.2.0}"
GITHUB_OWNER="${GITHUB_OWNER:-SaaSInfraLab}"
GITHUB_REPO="${GITHUB_REPO:-flux-gitops-pipeline}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
CLUSTER_PATH="${CLUSTER_PATH:-clusters/dev-environment}"

echo -e "${GREEN}Flux CD Bootstrap Installation${NC}"
echo "=================================="
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check cluster access
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot access Kubernetes cluster${NC}"
    echo "Please configure kubectl to access your cluster"
    exit 1
fi

echo -e "${GREEN}✓ kubectl is installed and configured${NC}"

# Check flux CLI
if ! command -v flux &> /dev/null; then
    echo -e "${YELLOW}Flux CLI not found. Installing...${NC}"
    
    # Detect OS
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac
    
    # Download and install Flux CLI
    FLUX_BINARY="flux_${FLUX_VERSION}_${OS}_${ARCH}.tar.gz"
    FLUX_URL="https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/${FLUX_BINARY}"
    
    echo "Downloading Flux CLI v${FLUX_VERSION}..."
    curl -LO "${FLUX_URL}"
    tar -xzf "${FLUX_BINARY}"
    
    # Install to /usr/local/bin (requires sudo) or ~/.local/bin
    if [ -w /usr/local/bin ]; then
        sudo mv flux /usr/local/bin/
    else
        mkdir -p ~/.local/bin
        mv flux ~/.local/bin/
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    rm -f "${FLUX_BINARY}"
    echo -e "${GREEN}✓ Flux CLI installed${NC}"
else
    INSTALLED_VERSION=$(flux --version | awk '{print $3}')
    echo -e "${GREEN}✓ Flux CLI is installed (version: ${INSTALLED_VERSION})${NC}"
fi

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ git is installed${NC}"
echo ""

# Prompt for GitHub token if not set
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}GitHub token not set.${NC}"
    echo "You can either:"
    echo "1. Set GITHUB_TOKEN environment variable"
    echo "2. Use SSH authentication (configure SSH keys)"
    echo "3. Enter token when prompted"
    echo ""
    read -p "Enter GitHub token (or press Enter to use SSH): " GITHUB_TOKEN
fi

# Bootstrap Flux CD
echo ""
echo -e "${YELLOW}Bootstrapping Flux CD...${NC}"
echo "Repository: ${GITHUB_OWNER}/${GITHUB_REPO}"
echo "Branch: ${GITHUB_BRANCH}"
echo "Path: ${CLUSTER_PATH}"
echo ""

if [ -n "$GITHUB_TOKEN" ]; then
    flux bootstrap github \
        --owner="${GITHUB_OWNER}" \
        --repository="${GITHUB_REPO}" \
        --branch="${GITHUB_BRANCH}" \
        --path="${CLUSTER_PATH}" \
        --token-auth \
        --personal
else
    flux bootstrap github \
        --owner="${GITHUB_OWNER}" \
        --repository="${GITHUB_REPO}" \
        --branch="${GITHUB_BRANCH}" \
        --path="${CLUSTER_PATH}" \
        --ssh-key-algorithm=ecdsa \
        --ssh-ecdsa-curve=p384
fi

# Wait for Flux components to be ready
echo ""
echo -e "${YELLOW}Waiting for Flux components to be ready...${NC}"
kubectl wait --for=condition=ready pod --all -n flux-system --timeout=300s

# Verify installation
echo ""
echo -e "${GREEN}Verifying installation...${NC}"
kubectl get pods -n flux-system

echo ""
echo -e "${GREEN}✓ Flux CD bootstrap completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Check Git repository sync: flux get sources git"
echo "2. Check Kustomizations: flux get kustomizations"
echo "3. View Flux events: flux events"
echo ""
echo "For more information, see:"
echo "- Getting Started: docs/getting-started.md"
echo "- Integration Guide: docs/integration-guide.md"

