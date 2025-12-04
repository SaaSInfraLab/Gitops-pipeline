# Argo CD Bootstrap Guide

Complete guide to bootstrap Argo CD on your EKS cluster and migrate from Flux CD.

## Prerequisites

- ✅ EKS cluster deployed and accessible
- ✅ `kubectl` configured to access your cluster
- ✅ GitHub repository: `SaaSInfraLab/gitops-pipeline`
- ✅ Write access to the repository (for webhook configuration)

## Quick Start

### Step 1: Install Argo CD

```bash
cd argocd/bootstrap
./install-argocd.sh
```

This will:
- Create `argocd` namespace
- Install Argo CD components
- Wait for all pods to be ready
- Display admin credentials

### Step 2: Access Argo CD UI

```bash
# Port-forward Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (from install script output)
```

### Step 3: Install Argo CD CLI (Optional)

**Windows:**
```powershell
# Using Chocolatey
choco install argocd

# Or download from: https://github.com/argoproj/argo-cd/releases
```

**Linux/Mac:**
```bash
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
```

**Login via CLI:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login localhost:8080
# Username: admin
# Password: (from install script)
```

### Step 4: Deploy Applications

**Option 1: Using App of Apps Pattern (Recommended)**

```bash
# Apply the App of Apps
kubectl apply -f ../app-of-apps.yaml

# This will automatically create all applications:
# - sample-saas-app-platform
# - sample-saas-app-analytics
# - monitoring-stack
# - infrastructure
```

**Option 2: Deploy Applications Individually**

```bash
# Deploy each application
kubectl apply -f ../applications/sample-saas-app-platform.yaml
kubectl apply -f ../applications/sample-saas-app-analytics.yaml
kubectl apply -f ../applications/monitoring-stack.yaml
kubectl apply -f ../applications/infrastructure.yaml
```

### Step 5: Verify Applications

```bash
# Check application status
kubectl get applications -n argocd

# Or using Argo CD CLI
argocd app list

# Check sync status
argocd app get sample-saas-app-platform
```

### Step 6: Uninstall Flux CD (After Verification)

**⚠️ Only do this after verifying Argo CD applications are working!**

```bash
./uninstall-flux.sh
```

## Application Configuration

### Sample SaaS App - Platform

- **Source**: `apps/sample-saas-app/overlays/platform`
- **Destination**: `platform` namespace
- **Sync Policy**: Automated with prune and self-heal

### Sample SaaS App - Analytics

- **Source**: `apps/sample-saas-app/overlays/analytics`
- **Destination**: `analytics` namespace
- **Sync Policy**: Automated with prune and self-heal

### Monitoring Stack

- **Source**: `clusters/dev-environment/apps/monitoring-stack`
- **Destination**: `monitoring` namespace
- **Sync Policy**: Automated with prune and self-heal

### Infrastructure

- **Source**: `infrastructure`
- **Destination**: Cluster-wide resources
- **Sync Policy**: Automated with prune and self-heal

## Git Repository Access

Argo CD needs access to your Git repository. By default, it uses anonymous access for public repositories.

### For Private Repositories

**Option 1: SSH Key (Recommended)**

1. Generate SSH key:
   ```bash
   ssh-keygen -t ed25519 -C "argocd" -f argocd-ssh-key
   ```

2. Add public key to GitHub:
   - Go to repository Settings → Deploy keys
   - Add `argocd-ssh-key.pub` with read access

3. Create Kubernetes secret:
   ```bash
   kubectl create secret generic argocd-repo-credentials \
     --from-file=sshPrivateKey=argocd-ssh-key \
     -n argocd
   ```

4. Update Application to use SSH:
   ```yaml
   source:
     repoURL: git@github.com:SaaSInfraLab/gitops-pipeline.git
     sshPrivateKeySecret:
       name: argocd-repo-credentials
       key: sshPrivateKey
   ```

**Option 2: HTTPS with Token**

1. Create GitHub Personal Access Token with `repo` scope

2. Create Kubernetes secret:
   ```bash
   kubectl create secret generic argocd-repo-credentials \
     --from-literal=type=git \
     --from-literal=url=https://github.com/SaaSInfraLab/gitops-pipeline \
     --from-literal=password=<your-token> \
     -n argocd
   ```

3. Update Application to use HTTPS:
   ```yaml
   source:
     repoURL: https://github.com/SaaSInfraLab/gitops-pipeline
     # Argo CD will automatically use the secret
   ```

## Webhook Configuration (Optional)

Configure webhooks for automatic sync on Git push:

1. **Get Argo CD Webhook URL:**
   ```bash
   # If using port-forward
   ARGOCD_URL="https://localhost:8080"
   
   # Or if using LoadBalancer/Ingress
   ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   ```

2. **Add GitHub Webhook:**
   - Go to repository Settings → Webhooks
   - Add webhook:
     - URL: `$ARGOCD_URL/api/webhook`
     - Content type: `application/json`
     - Events: `Just the push event`

3. **Enable webhook in Application:**
   ```yaml
   syncPolicy:
     syncOptions:
       - CreateNamespace=true
     # Webhook will trigger sync automatically
   ```

## Troubleshooting

### Applications Not Syncing

```bash
# Check application status
kubectl describe application sample-saas-app-platform -n argocd

# Check Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check repository connection
argocd repo list
```

### Authentication Issues

```bash
# Test repository access
argocd repo add https://github.com/SaaSInfraLab/gitops-pipeline \
  --username <username> \
  --password <token>

# Or for SSH
argocd repo add git@github.com:SaaSInfraLab/gitops-pipeline \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### Sync Failures

```bash
# Get detailed sync status
argocd app get sample-saas-app-platform

# Retry sync
argocd app sync sample-saas-app-platform

# Check resource events
kubectl get events -n platform
```

## Next Steps

After Argo CD is installed and applications are syncing:

1. ✅ Verify all applications are healthy
2. ✅ Test Git push → automatic sync
3. ✅ Configure webhooks (optional)
4. ✅ Uninstall Flux CD (if migrating)
5. ✅ Update documentation

## Documentation

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Application CRD Reference](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [Migration Guide](../MIGRATION_TO_ARGOCD.md)

