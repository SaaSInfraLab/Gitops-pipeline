# GitOps Pipeline - Automation Layer

![Argo CD](https://img.shields.io/badge/Argo-CD-EF7B4D?style=for-the-badge&logo=argo)
![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes)
![GitOps](https://img.shields.io/badge/Methodology-GitOps-success?style=for-the-badge)

> **Automation layer for deploying infrastructure and applications** to AWS EKS using Argo CD GitOps. This repository watches `cloudnative-saas-eks` for infrastructure changes and manages application deployments via GitOps.

## 🎯 What Is This Repository?

This is the **automation layer** that:
- ✅ **Watches** `cloudnative-saas-eks` repository for infrastructure configuration changes
- ✅ **Deploys** infrastructure via Terraform using GitHub Actions
- ✅ **Manages** Kubernetes applications via Argo CD GitOps
- ✅ **Automates** the complete CI/CD → GitOps workflow

**Key Principle**: This repository is **pure automation** - all configuration comes from `cloudnative-saas-eks`.

## 🏗️ Where Does It Help?

### Architecture Flow

```
┌─────────────────────────────────────────┐
│  cloudnative-saas-eks                   │
│  (Single Source of Truth)               │
│  - Configuration files (tfvars)         │
│  - Terraform code                       │
└──────────────┬──────────────────────────┘
               │
               │ (GitHub Actions watches)
               ▼
┌─────────────────────────────────────────┐
│  Gitops-pipeline (This Repo)            │
│  - GitHub Actions workflows             │
│  - Terraform deployment scripts         │
│  - Argo CD application definitions      │
│  - Kubernetes manifests                 │
└──────────────┬──────────────────────────┘
               │
               │ (Deploys to)
               ▼
┌─────────────────────────────────────────┐
│  AWS EKS Cluster                        │
│  - Infrastructure (VPC, EKS, RDS)       │
│  - Applications (Sample-saas-app)       │
│  - Monitoring (Prometheus/Grafana)      │
└─────────────────────────────────────────┘
```

### Integration Points

1. **With cloudnative-saas-eks**:
   - Watches for configuration changes
   - Deploys infrastructure automatically
   - Captures Terraform outputs

2. **With Sample-saas-app**:
   - Receives Docker image updates
   - Deploys applications via Argo CD
   - Manages multi-tenant deployments

3. **With AWS EKS**:
   - Deploys infrastructure via Terraform
   - Manages applications via Argo CD
   - Integrates with AWS Secrets Manager

## 🚀 How to Use It

### Prerequisites

- AWS EKS cluster (or will be created by this pipeline)
- GitHub repository with Actions enabled
- AWS credentials configured (via secrets or OIDC)

### Step 1: Configure GitHub Secrets

Add these secrets to this repository (**Settings → Secrets and variables → Actions**):

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for Terraform | AWS IAM → Create access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for Terraform | AWS IAM → Create access key |
| `ECR_BACKEND_REPO` | ECR repository name for backend | From Terraform: `terraform output ecr_backend_repository_name` |
| `ECR_FRONTEND_REPO` | ECR repository name for frontend | From Terraform: `terraform output ecr_frontend_repository_name` |
| `AWS_ROLE_ARN` | (Optional) IAM role for OIDC | From Terraform outputs or AWS Console |

### Step 2: Deploy Infrastructure

**Option A: Automated (Recommended)**
1. Push changes to `cloudnative-saas-eks` repository
2. GitHub Actions in this repo watches and deploys automatically

**Option B: Manual Trigger**
1. Go to **Actions → "Auto-Apply Infrastructure"**
2. Click **"Run workflow"**
3. Select environment: `dev`
4. Click **"Run workflow"**

### Step 3: Install Argo CD

```bash
# Navigate to bootstrap directory
cd argocd/bootstrap

# Run installation script
./install-argocd.sh

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Get admin password for windows
kubectl -n argocd get secret argocd-initial-admin-secret ` -o jsonpath="{.data.password}" | ` ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert ::FromBase64String($_)) }

# Port-forward Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: (from above)
```

### Step 4: Deploy Applications

```bash
# Deploy using App of Apps pattern
kubectl apply -f argocd/app-of-apps.yaml

# Verify applications
kubectl get applications -n argocd
argocd app list
```

## 📁 Repository Structure

```
Gitops-pipeline/
├── README.md                    # This file
├── .github/workflows/           # GitHub Actions workflows
│   ├── auto-apply-infra.yml     # Infrastructure deployment
│   ├── sync-ecr-repositories.yml # ECR repo name sync
│   └── destroy-infra.yml        # Infrastructure cleanup
├── scripts/                      # Deployment scripts
│   ├── deploy.sh                # Deploy infrastructure
│   ├── destroy.sh               # Destroy infrastructure
│   └── capture-outputs.sh       # Capture Terraform outputs
├── argocd/                       # Argo CD configuration
│   ├── app-of-apps.yaml         # App of Apps pattern
│   ├── applications/             # Application definitions
│   │   ├── infrastructure.yaml  # Infrastructure app
│   │   ├── monitoring-stack.yaml # Monitoring app
│   │   ├── sample-saas-app-platform.yaml
│   │   └── sample-saas-app-analytics.yaml
│   └── bootstrap/               # Argo CD installation
│       └── install-argocd.sh
├── apps/                         # Application manifests
│   └── sample-saas-app/         # Sample SaaS app
│       ├── base/                 # Base Kustomize config
│       └── overlays/             # Tenant overlays
│           ├── platform/        # Platform tenant
│           └── analytics/       # Analytics tenant
├── infrastructure/               # Infrastructure resources
│   ├── namespaces/               # Namespace definitions
│   ├── network-policies/         # Network policies
│   └── rbac/                     # RBAC configurations
└── examples/                     # Deployment examples
    ├── blue-green-deployment/
    ├── canary-deployment/
    └── rollback-scenario/
```

## 🔧 Key Components

### 1. Infrastructure Deployment

**What it does:**
- Watches `cloudnative-saas-eks` for configuration changes
- Deploys infrastructure via Terraform (VPC, EKS, RDS, ECR)
- Captures Terraform outputs to `infra_version.yaml`

**Workflow:** `.github/workflows/auto-apply-infra.yml`

**How to use:**
- Push changes to `cloudnative-saas-eks` → Auto-deploys
- Or manually trigger: **Actions → "Auto-Apply Infrastructure"**

### 2. Argo CD Applications

**What it does:**
- Manages Kubernetes applications via GitOps
- Automatically syncs when Git changes
- Provides web UI for application management

**Applications:**
- **sample-saas-app-platform**: Platform tenant deployment
- **sample-saas-app-analytics**: Analytics tenant deployment

**Note:** Infrastructure resources (namespaces, network policies) are managed by Terraform in `cloudnative-saas-eks`. Monitoring stack is not currently deployed.

**How to use:**
```bash
# Deploy all applications
kubectl apply -f argocd/app-of-apps.yaml

# Check status
argocd app list
argocd app get sample-saas-app-platform
```

### 3. ECR Repository Sync

**What it does:**
- Syncs ECR repository names from GitHub secrets
- Updates kustomization files with correct ECR paths
- Runs automatically or on manual trigger

**Workflow:** `.github/workflows/sync-ecr-repositories.yml`

**How to use:**
1. Add `ECR_BACKEND_REPO` and `ECR_FRONTEND_REPO` secrets
2. Go to **Actions → "Sync ECR Repository Names" → Run workflow**

### 4. Application Manifests

**What it does:**
- Defines Kubernetes deployments, services, configmaps
- Uses Kustomize for multi-tenant overlays
- Supports platform and analytics tenants

**Structure:**
- `apps/sample-saas-app/base/`: Common configuration
- `apps/sample-saas-app/overlays/platform/`: Platform tenant
- `apps/sample-saas-app/overlays/analytics/`: Analytics tenant

## 🔄 Complete CI/CD Flow

```
1. Developer pushes code to Sample-saas-app
   ↓
2. CI pipeline runs (tests, validation)
   ↓
3. CD pipeline builds Docker images
   ↓
4. Images pushed to ECR
   ↓
5. CD pipeline updates Gitops-pipeline with new image tags
   ↓
6. Argo CD detects Git changes
   ↓
7. Argo CD automatically deploys to EKS cluster
   ↓
8. Applications running in platform/analytics namespaces
```

## 📚 Quick Reference

### Deploy Infrastructure
```bash
# Automated (via GitHub Actions)
# Push to cloudnative-saas-eks → Auto-deploys

# Manual
cd scripts
./deploy.sh dev
```

### Deploy Applications
```bash
# Via Argo CD
kubectl apply -f argocd/app-of-apps.yaml

# Check status
argocd app list
kubectl get pods -n platform
kubectl get pods -n analytics
```

### Access Argo CD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
```

### Sync ECR Repositories
```bash
# Via GitHub Actions
# Actions → "Sync ECR Repository Names" → Run workflow
```

### Destroy Infrastructure
```bash
# Via GitHub Actions
# Actions → "Destroy Infrastructure" → Run workflow

# Or manual
cd scripts
./destroy.sh dev
```

## 🛡️ Security

- **AWS Access**: Use OIDC (recommended) or access keys
- **Git Access**: Use deploy keys or GitHub tokens
- **Secrets**: Stored in AWS Secrets Manager (for platform tenant)
- **Network**: Network policies enforce zero-trust model

## 🔗 Related Repositories

- **[cloudnative-saas-eks](https://github.com/SaaSInfraLab/cloudnative-saas-eks)**: Infrastructure configuration (single source of truth)
- **[Sample-saas-app](https://github.com/SaaSInfraLab/Sample-saas-app)**: Application code and CI/CD
- **[Terraform-modules](https://github.com/SaaSInfraLab/Terraform-modules)**: Reusable Terraform modules

## 📞 Support

- **Issues**: Open a GitHub issue
- **Documentation**: See inline comments in workflow files
- **Argo CD Docs**: https://argo-cd.readthedocs.io/

---

**Built with ❤️ for the CloudNative SaaS community**
