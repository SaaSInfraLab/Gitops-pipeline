# Quick Start Guide - GitOps Pipeline

## What Was Fixed

### ✅ Platform Tenant Issues
- **Problem**: AWS Secrets Manager integration had placeholder variables (`${AWS_ACCOUNT_ID}`, `${RDS_SECRET_ARN}`)
- **Fix**: Added clear documentation and instructions in `apps/sample-saas-app/overlays/platform/README.md`
- **Status**: Platform overlay now has proper documentation. You need to replace placeholders with actual values.

### ✅ Labels Updated
- **Problem**: All files had `managed-by: flux` labels
- **Fix**: Updated all labels to `managed-by: argocd` across:
  - Namespace definitions
  - Kustomization files
  - Infrastructure resources

### ✅ Infrastructure Application
- **What It Does**: 
  - Creates tenant namespaces (platform, analytics, data, monitoring)
  - Applies network policies (default-deny for security)
  - Manages RBAC resources
- **Documentation**: See [INFRASTRUCTURE_README.md](INFRASTRUCTURE_README.md)

### ✅ Monitoring Stack Application
- **What It Does**:
  - Deploys Prometheus (metrics collection)
  - Deploys Grafana (dashboards)
  - Deploys Alertmanager (alerts)
- **Status**: Application path updated. Full deployment requires Monitoring-stack resources.
- **Documentation**: See [MONITORING_STACK_README.md](MONITORING_STACK_README.md)

## Understanding the Components

### 1. Infrastructure Application

**Purpose**: Manages cluster-wide resources that need to exist before applications deploy.

**What it deploys**:
- ✅ Namespaces (platform, analytics, data, monitoring)
- ✅ Network Policies (security rules)
- ✅ RBAC (permissions) - add your roles here

**Why separate?**
- Resources apply cluster-wide
- Need to be deployed first
- Different lifecycle than applications

**Check status**:
```bash
kubectl get application infrastructure -n argocd
kubectl get namespaces | grep -E "platform|analytics|data|monitoring"
```

### 2. Monitoring Stack Application

**Purpose**: Provides observability for your cluster and applications.

**What it deploys**:
- ✅ Prometheus - Collects metrics from pods and services
- ✅ Grafana - Visualizes metrics in dashboards
- ✅ Alertmanager - Sends alerts when issues occur

**What it does**:
- Scrapes metrics from your applications
- Provides pre-configured dashboards
- Sends alerts for cluster health, node issues, pod failures

**Access**:
```bash
# Grafana
kubectl port-forward svc/dev-grafana -n monitoring 3000:80
# Open: http://localhost:3000

# Prometheus
kubectl port-forward svc/dev-prometheus -n monitoring 9090:9090
# Open: http://localhost:9090
```

### 3. Platform Tenant Application

**Purpose**: Deploys the application for the platform tenant with production-ready configuration.

**Features**:
- ✅ AWS Secrets Manager integration (IRSA)
- ✅ Automatic secret syncing from AWS Secrets Manager
- ✅ Full resource limits
- ✅ Production configuration

**Why it might not be working**:
1. AWS Secrets Manager not configured (see `apps/sample-saas-app/overlays/platform/README.md`)
2. IAM role `EKSSecretsManagerRole` doesn't exist
3. RDS secret ARN not set in `aws-secrets-manager.yaml`

**Fix**:
1. Edit `apps/sample-saas-app/overlays/platform/aws-secrets-manager.yaml`
2. Replace `${AWS_ACCOUNT_ID}` with your AWS account ID
3. Replace `${RDS_SECRET_ARN}` with your RDS secret ARN
4. Commit and push - Argo CD will sync

**Or disable AWS Secrets Manager**:
- Remove `aws-secrets-manager.yaml` and `secret-sync-job.yaml` from `kustomization.yaml`
- Use regular Kubernetes secrets instead

### 4. Analytics Tenant Application

**Purpose**: Deploys the application for the analytics tenant with optimized resource limits.

**Features**:
- ✅ Kubernetes secrets (simpler setup)
- ✅ Reduced resource limits (50m CPU, 256Mi memory)
- ✅ Metrics enabled
- ✅ ConfigMap-based configuration

**Why it works**:
- Simpler configuration (no AWS Secrets Manager)
- Uses standard Kubernetes secrets
- Less resource-intensive

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Infrastructure | ✅ Working | Deploys namespaces, network policies |
| Monitoring Stack | ⚠️ Partial | Application configured, needs Monitoring-stack resources |
| Platform Tenant | ⚠️ Needs Config | AWS Secrets Manager placeholders need values |
| Analytics Tenant | ✅ Working | Simpler setup, should work out of the box |

## Next Steps

### 1. Fix Platform Tenant

**Option A: Configure AWS Secrets Manager** (Recommended for production)
```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# Get RDS Secret ARN from AWS Secrets Manager console
# Or from Terraform outputs

# Edit the file
nano apps/sample-saas-app/overlays/platform/aws-secrets-manager.yaml

# Replace:
# - ${AWS_ACCOUNT_ID} with your account ID
# - ${RDS_SECRET_ARN} with your secret ARN

# Commit and push
git add apps/sample-saas-app/overlays/platform/aws-secrets-manager.yaml
git commit -m "Configure AWS Secrets Manager for platform tenant"
git push origin develop
```

**Option B: Disable AWS Secrets Manager** (Simpler, for testing)
```bash
# Edit kustomization.yaml
nano apps/sample-saas-app/overlays/platform/kustomization.yaml

# Remove these lines:
#   - aws-secrets-manager.yaml
#   - secret-sync-job.yaml

# Commit and push
git add apps/sample-saas-app/overlays/platform/kustomization.yaml
git commit -m "Disable AWS Secrets Manager for platform tenant"
git push origin develop
```

### 2. Set Up Monitoring Stack

The monitoring-stack application is configured but needs actual monitoring resources. You have two options:

**Option A: Use Helm Chart** (Recommended)
- Deploy kube-prometheus-stack Helm chart via Argo CD
- See `Monitoring-stack/helm/kube-prometheus-stack/values.yaml`

**Option B: Use Kustomize**
- Reference `Monitoring-stack/kustomize/base` in the kustomization
- Or copy monitoring resources into this repo

### 3. Configure GitHub Secrets

Add secrets to this repository (Gitops-pipeline):
- `AWS_ROLE_ARN` - IAM role for AWS access
- `ECR_BACKEND_REPO` - Backend ECR repository name
- `ECR_FRONTEND_REPO` - Frontend ECR repository name

See [SECRETS_SETUP.md](SECRETS_SETUP.md) for details.

### 4. Run Sync Workflow

After adding secrets, run the sync workflow:
1. Go to **Actions** → **"Sync ECR Repository Names"**
2. Click **"Run workflow"**
3. This updates ECR repository names in all kustomization files

## Verification

### Check All Applications

```bash
# List all Argo CD applications
kubectl get applications -n argocd

# Check each application status
argocd app get infrastructure
argocd app get monitoring-stack
argocd app get sample-saas-app-platform
argocd app get sample-saas-app-analytics
```

### Check Deployments

```bash
# Platform tenant
kubectl get pods -n platform
kubectl get deployments -n platform
kubectl get services -n platform

# Analytics tenant
kubectl get pods -n analytics
kubectl get deployments -n analytics
kubectl get services -n analytics
```

### Check Infrastructure

```bash
# Namespaces
kubectl get namespaces | grep -E "platform|analytics|data|monitoring"

# Network policies
kubectl get networkpolicies --all-namespaces
```

## Troubleshooting

### Platform Not Working

1. **Check AWS Secrets Manager setup**:
   ```bash
   kubectl get sa backend-sa -n platform
   kubectl get secretproviderclass db-secret-provider -n platform
   ```

2. **Check secret sync job**:
   ```bash
   kubectl get jobs -n platform
   kubectl logs -n platform job/secret-sync-trigger
   ```

3. **Check pod errors**:
   ```bash
   kubectl describe pod <pod-name> -n platform
   kubectl logs <pod-name> -n platform
   ```

### Monitoring Stack Not Working

1. **Check if monitoring namespace exists**:
   ```bash
   kubectl get namespace monitoring
   ```

2. **Check application sync status**:
   ```bash
   argocd app get monitoring-stack
   ```

3. **Deploy monitoring resources** (see Next Steps above)

## Documentation

- [Main README](README.md) - Complete overview
- [Infrastructure README](INFRASTRUCTURE_README.md) - Infrastructure components
- [Monitoring Stack README](MONITORING_STACK_README.md) - Monitoring setup
- [Secrets Setup](SECRETS_SETUP.md) - GitHub secrets configuration
- [Platform Overlay README](apps/sample-saas-app/overlays/platform/README.md) - Platform tenant setup

