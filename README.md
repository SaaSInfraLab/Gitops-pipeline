# GitOps Pipeline

![Argo CD](https://img.shields.io/badge/Argo-CD-EF7B4D?style=for-the-badge&logo=argo)
![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes)
![GitOps](https://img.shields.io/badge/Methodology-GitOps-success?style=for-the-badge)

> **Production-ready Argo CD GitOps setup** for automated Kubernetes deployments on AWS EKS. Complete solution with reusable templates, deployment strategies, and integration examples.

## 🎯 Overview

This repository provides a complete Argo CD GitOps pipeline setup for managing Kubernetes deployments on AWS EKS. It includes:

- ✅ **Complete Argo CD Bootstrap** - Automated installation and configuration
- ✅ **Application GitOps** - Sample-saas-app deployment via GitOps
- ✅ **Infrastructure as Code** - Namespace, RBAC, and network policy management
- ✅ **Reusable Templates** - Application definitions and configurations
- ✅ **Deployment Strategies** - Blue-green, canary, and rollback examples
- ✅ **Multi-Tenant Support** - Integration with existing multi-tenant infrastructure
- ✅ **Web UI** - Full-featured Argo CD UI for application management

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│  Sample-saas-app (GitHub)            │
│  - CI: Tests & Validation            │
│  - CD: Build Images → Update GitOps  │
└──────────────┬───────────────────────┘
               │
               │ (Git commit with new image tags)
               ▼
┌─────────────────────────────────────┐
│  Gitops-pipeline (GitHub)      │
│  - Kubernetes Manifests             │
│  - Kustomize Base + Overlays        │
│  - Multi-tenant Configurations      │
└──────────────┬──────────────────────┘
               │
               │ (Argo CD watches Git)
               ▼
┌──────────────────────────────────────┐
│  Argo CD (EKS Cluster)               │
│  - application-controller            │
│  - repo-server                       │
│  - server (Web UI)                   │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  Kubernetes Cluster (EKS)            │
│  ├── platform namespace              │
│  ├── analytics namespace             │
│  ├── Infrastructure (RBAC, Network)  │
│  └── Monitoring Stack                │
└──────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- AWS EKS cluster (created via `cloudnative-saas-eks`)
- `kubectl` configured to access your cluster
- Git repository access (GitHub, GitLab, etc.)
- GitHub Actions secrets configured (see [SECRETS_SETUP.md](SECRETS_SETUP.md))

### Install Argo CD

```bash
# Navigate to bootstrap directory
cd argocd/bootstrap

# Run the installation script
./install-argocd.sh
```

### Access Argo CD UI

```bash
# Port-forward Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (from install script output)
```

### Configure GitHub Secrets

Before deploying, configure GitHub Actions secrets in this repository:

1. Go to **Settings → Secrets and variables → Actions**
2. Add the following secrets (see [SECRETS_SETUP.md](SECRETS_SETUP.md) for details):
   - `AWS_ROLE_ARN` - IAM role for AWS access
   - `ECR_BACKEND_REPO` - Backend ECR repository name
   - `ECR_FRONTEND_REPO` - Frontend ECR repository name

3. Run the sync workflow to update kustomization files:
   - Go to **Actions → "Sync ECR Repository Names" → Run workflow**

### Deploy Applications

```bash
# Deploy using App of Apps pattern
kubectl apply -f argocd/app-of-apps.yaml
```

### Verify Installation

```bash
# Check Argo CD components
kubectl get pods -n argocd

# Check applications
kubectl get applications -n argocd

# Or use Argo CD CLI
argocd app list
```

> **📚 For detailed instructions, see [Argo CD README](ARGOCD_README.md)**

## 📁 Repository Structure

```
Gitops-pipeline/
├── README.md                          # This file
├── ARGOCD_README.md                   # Argo CD documentation
├── argocd/                            # Argo CD configuration
│   ├── applications/                 # Application definitions
│   │   ├── sample-saas-app-platform.yaml
│   │   ├── sample-saas-app-analytics.yaml
│   │   ├── monitoring-stack.yaml
│   │   └── infrastructure.yaml
│   ├── app-of-apps.yaml              # App of Apps pattern
│   └── bootstrap/                    # Bootstrap scripts
│       ├── install-argocd.sh
│       └── README.md
├── apps/                              # Application manifests
├── apps/                              # Application definitions
│   └── sample-saas-app/               # Sample SaaS app
│       ├── base/                      # Base Kustomize config
│       │   ├── backend-deployment.yaml
│       │   ├── frontend-deployment.yaml
│       │   ├── init-db-job.yaml
│       │   ├── image-repository.yaml
│       │   ├── image-update-automation.yaml
│       │   └── kustomization.yaml
│       └── overlays/                 # Tenant-specific overlays
│           ├── platform/             # Platform tenant overlay
│           │   ├── namespace.yaml
│           │   ├── aws-secrets-manager.yaml
│           │   ├── secret-sync-job.yaml
│           │   └── kustomization.yaml
│           ├── analytics/            # Analytics tenant overlay
│           │   ├── namespace.yaml
│           │   └── kustomization.yaml
│           ├── dev/                  # Dev environment overlay
│           └── prod/                 # Prod environment overlay
├── infrastructure/                   # Infrastructure components
│   ├── namespaces/                   # Namespace definitions
│   ├── network-policies/             # Network policy configs
│   └── rbac/                         # RBAC configurations
├── templates/                        # Reusable templates
│   ├── helm-release-template.yaml
│   ├── kustomization-template.yaml
│   └── git-repository-template.yaml
├── examples/                          # Deployment strategy examples
│   ├── blue-green-deployment/        # Blue-green deployment example
│   ├── canary-deployment/            # Canary deployment example
│   └── rollback-scenario/            # Rollback scenario example
└── docs/                              # Documentation (see ARGOCD_README.md for details)
```

## 🔧 Key Components

### Argo CD Applications

Applications are defined using Argo CD Application CRDs:

- **sample-saas-app-platform**: Platform tenant deployment with AWS Secrets Manager integration
- **sample-saas-app-analytics**: Analytics tenant deployment with resource limits
- **monitoring-stack**: Prometheus/Grafana/Alertmanager monitoring stack
- **infrastructure**: Cluster-wide infrastructure (namespaces, RBAC, network policies)

See [INFRASTRUCTURE_README.md](INFRASTRUCTURE_README.md) and [MONITORING_STACK_README.md](MONITORING_STACK_README.md) for detailed information.

### Argo CD Bootstrap

The bootstrap process installs Argo CD components:

- **application-controller**: Manages application lifecycle and sync
- **repo-server**: Handles Git repository operations
- **server**: Web UI and API server
- **dex**: Authentication server (optional)

### Application Definitions

Applications are defined using Kustomize overlays for multi-tenant and environment-specific configurations:

- **Base**: Common configuration shared across all tenants (deployments, services, init jobs)
- **Overlays**: Tenant-specific customizations:
  - **platform**: Production tenant with AWS Secrets Manager integration
  - **analytics**: Analytics tenant with resource limits
  - **dev/prod**: Environment-specific overlays (optional)

### Infrastructure Components

Infrastructure resources managed via GitOps:

- **Namespaces**: Multi-tenant namespace definitions (platform, analytics, data, monitoring)
- **Network Policies**: Pod-to-pod communication rules (default-deny for security)
- **RBAC**: Role-based access control configurations (add your roles here)

**What Infrastructure Does:**
- Creates and manages tenant namespaces before applications deploy
- Applies network security policies (zero-trust model)
- Manages RBAC for applications and services
- Ensures proper namespace labels and organization

See [INFRASTRUCTURE_README.md](INFRASTRUCTURE_README.md) for details.

### Monitoring Stack

The monitoring stack provides:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards
- **Alertmanager**: Alert routing and notifications
- **ServiceMonitors**: Automatic metric scraping from applications

**What Monitoring Stack Does:**
- Collects cluster and application metrics
- Provides pre-configured dashboards for Kubernetes and applications
- Sends alerts for cluster health, node issues, and pod failures
- Integrates with applications via ServiceMonitors

See [MONITORING_STACK_README.md](MONITORING_STACK_README.md) for details.

## 📚 Documentation

- [Argo CD README](ARGOCD_README.md) - Complete Argo CD guide and documentation
- [Bootstrap Guide](argocd/bootstrap/README.md) - Detailed installation and setup instructions
- [Infrastructure README](INFRASTRUCTURE_README.md) - Infrastructure components explained
- [Monitoring Stack README](MONITORING_STACK_README.md) - Monitoring setup and usage
- [Secrets Setup](SECRETS_SETUP.md) - GitHub Actions secrets configuration

## 🔗 Integration

### With cloudnative-saas-eks

This repository integrates seamlessly with the [cloudnative-saas-eks](https://github.com/SaaSInfraLab/cloudnative-saas-eks) infrastructure:

- Deploys to EKS clusters created by Terraform
- Uses existing namespaces (platform, analytics, data)
- Integrates with AWS Secrets Manager via IRSA
- Supports multi-tenant deployments

### With Sample-saas-app

Fully GitOps deployment of the [Sample-saas-app](https://github.com/SaaSInfraLab/Sample-saas-app):

**Complete CI/CD → GitOps Workflow:**
```
1. Developer pushes code to Sample-saas-app
   ↓
2. CI pipeline (Sample-saas-app) runs tests and validation
   ↓
3. CD pipeline (Sample-saas-app) triggers:
   - Builds Docker images (backend + frontend)
   - Pushes images to ECR with tags (sha, latest, branch)
   - Updates this GitOps repository with new image tags
   ↓
4. Argo CD detects Git repository changes (via webhook or polling)
   ↓
5. Argo CD automatically syncs and deploys to cluster
   - Platform tenant namespace
   - Analytics tenant namespace
```

**Key Features:**
- ✅ **Fully GitOps**: No kubectl in CI/CD, all deployments via Git
- ✅ **Multi-Tenant**: Separate deployments for platform and analytics tenants
- ✅ **Automatic Updates**: CI/CD automatically updates image tags in Git
- ✅ **Web UI**: Visual application management via Argo CD UI
- ✅ **Secrets Management**: Platform tenant uses AWS Secrets Manager via IRSA
- ✅ **Environment Isolation**: Tenant-specific namespaces and configurations

**Configuration:**
- Base manifests in `apps/sample-saas-app/base/`
- Platform overlay: `apps/sample-saas-app/overlays/platform/` (with AWS Secrets Manager)
- Analytics overlay: `apps/sample-saas-app/overlays/analytics/` (with resource limits)
- Cluster Kustomizations: `clusters/dev-environment/apps/sample-saas-app-*/`

**Platform vs Analytics:**
- **Platform**: Uses AWS Secrets Manager for RDS credentials via IRSA (IAM Roles for Service Accounts)
- **Analytics**: Uses standard Kubernetes secrets, optimized for analytics workloads with resource limits
- Both share the same base application code but have different configurations

See [GitOps Integration Summary](docs/gitops-integration-summary.md) for detailed workflow documentation.

### Required GitHub Secrets

For the CI/CD → GitOps integration to work, configure these secrets in the **Sample-saas-app** repository:

| Secret Name | Description | Required For |
|------------|-------------|--------------|
| `AWS_ROLE_ARN` | IAM role ARN for ECR access | Building and pushing images |
| `ECR_BACKEND_REPO` | ECR repository name for backend | Backend image push |
| `ECR_FRONTEND_REPO` | ECR repository name for frontend | Frontend image push |
| `GITOPS_REPO_TOKEN` | GitHub Personal Access Token with `repo` scope | Updating GitOps repository |

**Setup Instructions:**
1. Create a GitHub Personal Access Token (PAT) with `repo` scope
2. Add it as `GITOPS_REPO_TOKEN` secret in Sample-saas-app repository
3. Ensure the token has write access to `Gitops-pipeline` repository

## 🎯 Use Cases

### Continuous Deployment via GitOps

Automatically deploy applications when CI/CD updates Git:

```bash
# Developer workflow (Sample-saas-app)
git commit -am "Add new feature"
git push origin main

# CI/CD automatically:
# 1. Builds and pushes images to ECR
# 2. Updates Gitops-pipeline Git repo with new tags
# 3. Argo CD detects changes and deploys to cluster
```

### Manual GitOps Updates

Manually update application configurations:

```bash
# Make changes to application manifests
git commit -am "Update application configuration"
git push

# Argo CD automatically syncs and deploys
```

### Multi-Tenant Management

Manage multiple tenants (platform, analytics) with Kustomize overlays:

```bash
# Check platform tenant deployment
argocd app get sample-saas-app-platform

# Check analytics tenant deployment
argocd app get sample-saas-app-analytics

# View tenant-specific resources
kubectl get all -n platform
kubectl get all -n analytics
```

### Multi-Environment Management

Manage dev, staging, and production environments with Kustomize overlays:

```bash
# Deploy to dev (if configured)
kubectl apply -k apps/sample-saas-app/overlays/dev

# Deploy to prod (if configured)
kubectl apply -k apps/sample-saas-app/overlays/prod
```

### Image Update Automation

Two methods for updating container images:

**CI/CD Pipeline Updates (Current Implementation)**
- Sample-saas-app CD pipeline builds images and updates GitOps repo
- Updates image tags in `base/kustomization.yaml` and overlay files
- Argo CD detects Git changes and deploys automatically

**Optional: Argo CD Image Updater**
- Can be configured separately for automated image scanning
- Updates Git repository with new tags
- See [Argo CD Image Updater documentation](https://argocd-image-updater.readthedocs.io/)

## 🛡️ Security Best Practices

- **Git Authentication**: Use SSH keys or deploy keys for Git access
- **IRSA**: IAM Roles for Service Accounts for AWS resource access
- **Secrets Management**: Integrate with AWS Secrets Manager
- **RBAC**: Fine-grained access control for Argo CD
- **Network Policies**: Restrict pod-to-pod communication

## 📊 Monitoring

Argo CD provides built-in observability:

```bash
# Check application status
argocd app list

# View application health
argocd app get sample-saas-app-platform

# Check sync history
argocd app history sample-saas-app-platform

# View application logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Related Projects

- [cloudnative-saas-eks](https://github.com/SaaSInfraLab/cloudnative-saas-eks) - EKS infrastructure setup
- [Sample-saas-app](https://github.com/SaaSInfraLab/Sample-saas-app) - Sample multi-tenant SaaS application
- [monitoring-stack](https://github.com/SaaSInfraLab/monitoring-stack) - Prometheus/Grafana monitoring

## 📞 Support

For issues and questions:

- Open an issue on GitHub
- Check the [bootstrap guide](argocd/bootstrap/README.md)
- Review the [Argo CD documentation](https://argo-cd.readthedocs.io/)
- See [Argo CD README](ARGOCD_README.md) for complete documentation

---

**Built with ❤️ for the CloudNative SaaS community**

