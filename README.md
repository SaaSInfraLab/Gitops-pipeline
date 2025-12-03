# Flux GitOps Pipeline

![Flux CD](https://img.shields.io/badge/Flux-CD-2C8EBB?style=for-the-badge&logo=fluxcd)
![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes)
![GitOps](https://img.shields.io/badge/Methodology-GitOps-success?style=for-the-badge)

> **Production-ready Flux CD GitOps setup** for automated Kubernetes deployments on AWS EKS. Complete solution with reusable templates, deployment strategies, and integration examples.

## 🎯 Overview

This repository provides a complete Flux CD GitOps pipeline setup for managing Kubernetes deployments on AWS EKS. It includes:

- ✅ **Complete Flux CD Bootstrap** - Automated installation and configuration
- ✅ **Application GitOps** - Sample-saas-app deployment via GitOps
- ✅ **Infrastructure as Code** - Namespace, RBAC, and network policy management
- ✅ **Reusable Templates** - Helm releases, Kustomize, and Git repository sources
- ✅ **Deployment Strategies** - Blue-green, canary, and rollback examples
- ✅ **Multi-Tenant Support** - Integration with existing multi-tenant infrastructure

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
│  flux-gitops-pipeline (GitHub)      │
│  - Kubernetes Manifests             │
│  - Kustomize Base + Overlays        │
│  - Multi-tenant Configurations      │
└──────────────┬──────────────────────┘
               │
               │ (Flux watches Git)
               ▼
┌──────────────────────────────────────┐
│  Flux CD (EKS Cluster)               │
│  - source-controller                 │
│  - kustomize-controller              │
│  - image-automation-controller       │
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
- `flux` CLI installed (or use the bootstrap script)
- Git repository access (GitHub, GitLab, etc.)

### Bootstrap Flux CD

```bash
# Navigate to bootstrap directory
cd bootstrap

# Run the bootstrap script
./install.sh

# Or manually bootstrap Flux
flux bootstrap github \
  --owner=SaaSInfraLab \
  --repository=flux-gitops-pipeline \
  --branch=main \
  --path=clusters/dev-environment
```

### Verify Installation

```bash
# Check Flux components
kubectl get pods -n flux-system

# Check Git repository sync
flux get sources git

# Check application sync
flux get kustomizations
```

## 📁 Repository Structure

```
flux-gitops-pipeline/
├── README.md                          # This file
├── bootstrap/                         # Flux CD bootstrap configuration
│   ├── flux-system/                   # Flux system namespace
│   │   ├── gotk-components.yaml       # Flux components
│   │   ├── gotk-sync.yaml             # Sync configuration
│   │   └── kustomization.yaml
│   └── install.sh                     # Bootstrap script
├── clusters/                          # Cluster-specific configs
│   └── dev-environment/               # Dev cluster config
│       ├── flux-system/               # Flux system config
│       ├── apps/                      # Application deployments
│       │   ├── sample-saas-app/       # Main app reference
│       │   ├── sample-saas-app-platform/  # Platform tenant
│       │   ├── sample-saas-app-analytics/ # Analytics tenant
│       │   └── monitoring-stack/      # Monitoring stack config
│       └── infrastructure/            # Infrastructure configs
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
└── docs/                              # Documentation
    ├── getting-started.md
    ├── integration-guide.md
    ├── gitops-integration-summary.md  # GitOps integration details
    └── troubleshooting.md
```

## 🔧 Key Components

### Flux CD Bootstrap

The bootstrap process installs Flux CD components and configures Git repository synchronization:

- **source-controller**: Manages Git and Helm repository sources
- **kustomize-controller**: Applies Kustomize overlays
- **helm-controller**: Manages Helm releases
- **image-reflector-controller**: Scans container image repositories
- **image-automation-controller**: Updates Git based on image changes

### Application Definitions

Applications are defined using Kustomize overlays for multi-tenant and environment-specific configurations:

- **Base**: Common configuration shared across all tenants (deployments, services, init jobs)
- **Overlays**: Tenant-specific customizations:
  - **platform**: Production tenant with AWS Secrets Manager integration
  - **analytics**: Analytics tenant with resource limits
  - **dev/prod**: Environment-specific overlays (optional)

### Infrastructure Components

Infrastructure resources managed via GitOps:

- **Namespaces**: Multi-tenant namespace definitions
- **Network Policies**: Pod-to-pod communication rules
- **RBAC**: Role-based access control configurations

## 📚 Documentation

- [Getting Started Guide](docs/getting-started.md) - Detailed installation and setup
- [Integration Guide](docs/integration-guide.md) - Integration with cloudnative-saas-eks
- [GitOps Integration Summary](docs/gitops-integration-summary.md) - Complete CI/CD → GitOps workflow
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

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
4. Flux CD detects Git repository changes
   ↓
5. Flux automatically syncs and deploys to cluster
   - Platform tenant namespace
   - Analytics tenant namespace
```

**Key Features:**
- ✅ **Fully GitOps**: No kubectl in CI/CD, all deployments via Git
- ✅ **Multi-Tenant**: Separate deployments for platform and analytics tenants
- ✅ **Automatic Updates**: CI/CD automatically updates image tags in Git
- ✅ **Image Automation**: Flux ImageUpdateAutomation for automated image scanning
- ✅ **Secrets Management**: Platform tenant uses AWS Secrets Manager via IRSA
- ✅ **Environment Isolation**: Tenant-specific namespaces and configurations

**Configuration:**
- Base manifests in `apps/sample-saas-app/base/`
- Platform overlay: `apps/sample-saas-app/overlays/platform/`
- Analytics overlay: `apps/sample-saas-app/overlays/analytics/`
- Cluster Kustomizations: `clusters/dev-environment/apps/sample-saas-app-*/`

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
3. Ensure the token has write access to `flux-gitops-pipeline` repository

## 🎯 Use Cases

### Continuous Deployment via GitOps

Automatically deploy applications when CI/CD updates Git:

```bash
# Developer workflow (Sample-saas-app)
git commit -am "Add new feature"
git push origin main

# CI/CD automatically:
# 1. Builds and pushes images to ECR
# 2. Updates flux-gitops-pipeline Git repo with new tags
# 3. Flux detects changes and deploys to cluster
```

### Manual GitOps Updates

Manually update application configurations:

```bash
# Make changes to application manifests
git commit -am "Update application configuration"
git push

# Flux automatically syncs and deploys
```

### Multi-Tenant Management

Manage multiple tenants (platform, analytics) with Kustomize overlays:

```bash
# Check platform tenant deployment
flux get kustomizations sample-saas-app-platform

# Check analytics tenant deployment
flux get kustomizations sample-saas-app-analytics

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

**Method 1: CI/CD Pipeline Updates (Current Implementation)**
- Sample-saas-app CD pipeline builds images and updates GitOps repo
- Updates image tags in `base/kustomization.yaml` and overlay files
- Flux detects Git changes and deploys automatically

**Method 2: Flux ImageUpdateAutomation (Optional)**
- Automatically scans ECR for new images
- Updates Git repository with new tags
- Configured in `apps/sample-saas-app/base/image-update-automation.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata:
  name: sample-saas-app
spec:
  update:
    path: ./apps/sample-saas-app
    strategy: Setters
```

## 🛡️ Security Best Practices

- **Git Authentication**: Use SSH keys or deploy keys for Git access
- **IRSA**: IAM Roles for Service Accounts for AWS resource access
- **Secrets Management**: Integrate with AWS Secrets Manager
- **RBAC**: Fine-grained access control for Flux components
- **Network Policies**: Restrict pod-to-pod communication

## 📊 Monitoring

Flux CD provides built-in observability:

```bash
# Check sync status
flux get kustomizations

# View events
flux events

# Check logs
kubectl logs -n flux-system -l app=source-controller
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
- Check the [troubleshooting guide](docs/troubleshooting.md)
- Review the [Flux CD documentation](https://fluxcd.io/docs/)

---

**Built with ❤️ for the CloudNative SaaS community**

