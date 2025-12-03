# Getting Started with Flux GitOps Pipeline

This guide will walk you through setting up Flux CD on your EKS cluster and deploying applications via GitOps.

## Prerequisites

### Required Tools

- **kubectl** >= 1.24 (configured to access your EKS cluster)
- **flux** CLI >= 2.0.0
- **git** >= 2.0
- **AWS CLI** (for EKS cluster access)

### AWS Requirements

- EKS cluster created via `cloudnative-saas-eks`
- IAM permissions to create resources in the cluster
- Git repository access (GitHub, GitLab, etc.)

### Verify Prerequisites

```bash
# Check kubectl
kubectl version --client

# Check cluster access
kubectl cluster-info

# Check flux CLI (install if needed)
flux --version

# Check git
git --version
```

## Installation

### Step 1: Install Flux CLI

#### macOS

```bash
brew install fluxcd/tap/flux
```

#### Linux

```bash
# Download and install
curl -s https://fluxcd.io/install.sh | sudo bash
```

#### Windows

```powershell
# Using Chocolatey
choco install flux

# Or download from GitHub releases
```

### Step 2: Bootstrap Flux CD

#### Option A: Using Bootstrap Script

```bash
cd flux-gitops-pipeline/bootstrap
./install.sh
```

The script will:
1. Check prerequisites
2. Install Flux CLI if needed
3. Bootstrap Flux CD on your cluster
4. Configure Git repository sync

#### Option B: Manual Bootstrap

```bash
# For GitHub
flux bootstrap github \
  --owner=SaaSInfraLab \
  --repository=flux-gitops-pipeline \
  --branch=main \
  --path=clusters/dev-environment \
  --personal

# For GitLab
flux bootstrap gitlab \
  --owner=your-group \
  --repository=flux-gitops-pipeline \
  --branch=main \
  --path=clusters/dev-environment \
  --token-auth
```

### Step 3: Verify Installation

```bash
# Check Flux components
kubectl get pods -n flux-system

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# helm-controller-xxx                       1/1     Running   0          2m
# kustomize-controller-xxx                  1/1     Running   0          2m
# notification-controller-xxx               1/1     Running   0          2m
# source-controller-xxx                     1/1     Running   0          2m

# Check Git repository sync
flux get sources git

# Check Kustomizations
flux get kustomizations
```

## Configuration

### Git Repository Setup

1. **Fork or clone** this repository
2. **Update Git repository references** in:
   - `clusters/dev-environment/flux-system/kustomization.yaml`
   - `bootstrap/flux-system/gotk-sync.yaml`

3. **Configure authentication**:
   - **GitHub**: Use personal access token or SSH keys
   - **GitLab**: Use deploy tokens or SSH keys

### Cluster Configuration

Edit `clusters/dev-environment/flux-system/kustomization.yaml` to match your setup:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../bootstrap/flux-system/gotk-components.yaml
  - ../../../bootstrap/flux-system/gotk-sync.yaml

patches:
  - patch: |-
      - op: replace
        path: /spec/url
        value: https://github.com/YOUR_ORG/YOUR_REPO
    target:
      kind: GitRepository
      name: flux-system
```

## Deploying Applications

### Deploy Sample SaaS App

```bash
# Create a Kustomization for the app
flux create kustomization sample-saas-app \
  --source=flux-system \
  --path="./apps/sample-saas-app/overlays/dev" \
  --prune=true \
  --interval=5m

# Or apply the existing configuration
kubectl apply -f clusters/dev-environment/apps/sample-saas-app/kustomization.yaml
```

### Deploy Infrastructure

```bash
# Deploy namespaces, RBAC, and network policies
kubectl apply -f clusters/dev-environment/infrastructure/kustomization.yaml
```

## Monitoring

### Check Sync Status

```bash
# List all Kustomizations
flux get kustomizations

# Check specific Kustomization
flux get kustomization sample-saas-app

# View events
flux events --kind Kustomization
```

### View Logs

```bash
# Source controller logs
kubectl logs -n flux-system -l app=source-controller

# Kustomize controller logs
kubectl logs -n flux-system -l app=kustomize-controller

# Helm controller logs
kubectl logs -n flux-system -l app=helm-controller
```

## Common Tasks

### Update Application Configuration

1. **Edit** the Kustomization files in `apps/sample-saas-app/`
2. **Commit** changes to Git
3. **Push** to remote repository
4. **Flux automatically syncs** (default interval: 5 minutes)

```bash
# Make changes
vim apps/sample-saas-app/overlays/dev/kustomization.yaml

# Commit and push
git add .
git commit -m "Update app configuration"
git push origin main

# Force immediate sync (optional)
flux reconcile kustomization sample-saas-app
```

### Add New Application

1. **Create** application directory structure:
   ```bash
   mkdir -p apps/my-app/base
   mkdir -p apps/my-app/overlays/dev
   ```

2. **Add** Kubernetes manifests to `base/`

3. **Create** Kustomization files

4. **Add** to cluster configuration:
   ```bash
   mkdir -p clusters/dev-environment/apps/my-app
   # Create kustomization.yaml
   ```

5. **Commit and push** to Git

### Image Update Automation

Configure automatic image updates:

```bash
flux create image repository backend \
  --image=821368347884.dkr.ecr.us-east-1.amazonaws.com/saas-infra-lab-dev-backend \
  --interval=1h

flux create image policy backend \
  --image-ref=backend \
  --select-semver=">=1.0.0"

flux create image update sample-saas-app \
  --git-repo-ref=sample-saas-app \
  --checkout-branch=main \
  --author-name=flux \
  --author-email=flux@example.com \
  --commit-template="{{range .Updated.Images}}{{println .}}{{end}}"
```

## Troubleshooting

### Flux Components Not Starting

```bash
# Check pod status
kubectl get pods -n flux-system

# Check events
kubectl describe pod -n flux-system <pod-name>

# Check logs
kubectl logs -n flux-system <pod-name>
```

### Git Repository Sync Issues

```bash
# Check Git repository source
flux get sources git

# Reconcile manually
flux reconcile source git flux-system

# Check authentication
kubectl get secret -n flux-system flux-system -o yaml
```

### Application Not Deploying

```bash
# Check Kustomization status
flux get kustomization sample-saas-app

# Check events
flux events --kind Kustomization --name sample-saas-app

# Suspend and resume
flux suspend kustomization sample-saas-app
flux resume kustomization sample-saas-app
```

For more troubleshooting, see [troubleshooting.md](troubleshooting.md).

## Next Steps

- Read the [Integration Guide](integration-guide.md) for cloudnative-saas-eks integration
- Explore [deployment examples](../examples/) for blue-green and canary strategies
- Configure [image automation](https://fluxcd.io/docs/components/image/) for automatic updates

## Additional Resources

- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Best Practices](https://www.gitops.tech/)

