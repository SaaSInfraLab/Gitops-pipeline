# Flux CD Bootstrap

Simple guide to bootstrap Flux CD on your EKS cluster.

## Prerequisites

- ✅ EKS cluster deployed and accessible
- ✅ `kubectl` configured to access your cluster
- ✅ `flux` CLI installed (see installation below)
- ✅ GitHub repository: `SaaSInfraLab/flux-gitops-pipeline`
- ✅ GitHub token (PAT) or SSH keys configured

## Install Flux CLI

### Windows (Git Bash / PowerShell)

**Option 1: Using Chocolatey**
```powershell
choco install flux
```

**Option 2: Using Scoop**
```powershell
scoop install flux
```

**Option 3: Manual Download**
1. Download: https://github.com/fluxcd/flux2/releases/download/v2.3.0/flux_2.3.0_windows_amd64.zip
2. Extract and add `flux.exe` to your PATH

### Linux / Mac

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

## Install Flux Components First

If you get errors about missing CRDs (like "no matches for kind GitRepository"), install Flux components first:

```bash
# Install Flux components
flux install

# Verify
kubectl get pods -n flux-system
kubectl get crds | grep flux
```

Then proceed with bootstrap below.

## Bootstrap Flux CD

### Using GitHub Token (Recommended)

**Important:** The token must have write access to the repository. If you get "authorization failed" or "Permission denied", check:

1. **Token belongs to account with repository access**
   - The token must be from an account that has write access to `SaaSInfraLab/flux-gitops-pipeline`
   - If you're using a personal account token, ensure you're a collaborator or the repository owner

2. **Token has correct scopes**
   - `repo` scope (full control of private repositories)
   - `workflow` scope (optional, for workflow updates)

3. **Repository permissions**
   - Ensure your GitHub account has write access to the repository
   - Check: https://github.com/SaaSInfraLab/flux-gitops-pipeline/settings/access

```bash
flux bootstrap github \
  --owner=SaaSInfraLab \
  --repository=flux-gitops-pipeline \
  --branch=develop \
  --path=clusters/dev-environment \
  --token-auth \
  --personal
```

When prompted, paste your GitHub token (starts with `ghp_...` or `github_pat_...`).

**Alternative:** Set token as environment variable:
```bash
export GITHUB_TOKEN='your-token-here'
flux bootstrap github \
  --owner=SaaSInfraLab \
  --repository=flux-gitops-pipeline \
  --branch=develop \
  --path=clusters/dev-environment \
  --token-auth \
  --personal
```

### Using SSH (Alternative)

```bash
flux bootstrap github \
  --owner=SaaSInfraLab \
  --repository=flux-gitops-pipeline \
  --branch=develop \
  --path=clusters/dev-environment \
  --ssh-key-algorithm=ecdsa \
  --ssh-ecdsa-curve=p384
```

## Verify Installation

```bash
# Check Flux pods
kubectl get pods -n flux-system

# Check Git repository sync
flux get sources git

# Check Kustomizations
flux get kustomizations
```

## What Gets Installed

- **source-controller**: Manages Git repository sources
- **kustomize-controller**: Applies Kustomize manifests
- **helm-controller**: Manages Helm releases
- **image-reflector-controller**: Scans container images
- **image-automation-controller**: Updates Git based on image changes

## Next Steps

After bootstrap:
1. Flux will automatically sync your Git repository
2. Applications will be deployed from `clusters/dev-environment/apps/`
3. Infrastructure will be deployed from `clusters/dev-environment/infrastructure/`

## Troubleshooting

### Flux CLI Not Found
- Install Flux CLI using one of the methods above
- Verify: `flux version`

### Authentication Failed
- Check GitHub token has `repo` scope
- Or ensure SSH keys are configured with GitHub

### Cluster Not Accessible
- Verify: `kubectl get nodes`
- Update kubeconfig: `aws eks update-kubeconfig --name <cluster-name> --region <region>`

## Documentation

- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Bootstrap Guide](https://fluxcd.io/flux/installation/bootstrap/)

