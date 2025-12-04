# Argo CD GitOps Pipeline

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
┌──────────────────────────────────────┐
│  Sample-saas-app (GitHub)            │
│  - CI: Tests & Validation            │
│  - CD: Build Images → Update GitOps  │
└──────────────┬───────────────────────┘
               │
               │ (Git commit with new image tags)
               ▼
┌─────────────────────────────────────┐
│  Gitops-pipeline (GitHub)           │
│  - Kubernetes Manifests             │
│  - Kustomize Base + Overlays        │
│  - Multi-tenant Configurations      │
│  - Argo CD Applications             │
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

### Deploy Applications

```bash
# Deploy using App of Apps pattern
kubectl apply -f ../app-of-apps.yaml

# Or deploy individually
kubectl apply -f argocd/applications/sample-saas-app-platform.yaml
kubectl apply -f argocd/applications/sample-saas-app-analytics.yaml
kubectl apply -f argocd/applications/monitoring-stack.yaml
kubectl apply -f argocd/applications/infrastructure.yaml
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

## 📁 Repository Structure

```
Gitops-pipeline/
├── README.md                          # Main documentation
├── ARGOCD_README.md                   # This file
├── MIGRATION_TO_ARGOCD.md             # Migration guide from Flux
├── argocd/                            # Argo CD configuration
│   ├── applications/                 # Application definitions
│   │   ├── sample-saas-app-platform.yaml
│   │   ├── sample-saas-app-analytics.yaml
│   │   ├── monitoring-stack.yaml
│   │   └── infrastructure.yaml
│   ├── app-of-apps.yaml              # App of Apps pattern
│   └── bootstrap/                    # Bootstrap scripts
│       ├── install-argocd.sh
│       ├── uninstall-flux.sh
│       └── README.md
├── apps/                              # Application manifests
│   └── sample-saas-app/              # Sample SaaS app
│       ├── base/                     # Base Kustomize config
│       └── overlays/                  # Tenant-specific overlays
│           ├── platform/
│           └── analytics/
├── infrastructure/                    # Infrastructure components
│   ├── namespaces/
│   ├── network-policies/
│   └── rbac/
└── examples/                          # Deployment strategy examples
```

## 🔧 Key Components

### Argo CD Applications

Applications are defined using Argo CD Application CRDs:

- **sample-saas-app-platform**: Platform tenant deployment
- **sample-saas-app-analytics**: Analytics tenant deployment
- **monitoring-stack**: Prometheus/Grafana monitoring
- **infrastructure**: Cluster-wide infrastructure resources

### Application Definitions

Each application references:
- **Source**: Git repository URL and path
- **Destination**: Kubernetes cluster and namespace
- **Sync Policy**: Automated sync, prune, self-heal

### Multi-Tenant Support

Applications are deployed to tenant-specific namespaces:
- **platform**: Production tenant with AWS Secrets Manager
- **analytics**: Analytics tenant with resource limits

## 📚 Documentation

- [Bootstrap Guide](argocd/bootstrap/README.md) - Detailed installation and setup
- [Migration Guide](MIGRATION_TO_ARGOCD.md) - Migrating from Flux CD
- [Integration Guide](docs/integration-guide.md) - Integration with cloudnative-saas-eks

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

### Manual Application Management

Use Argo CD UI or CLI to manage applications:

```bash
# List all applications
argocd app list

# Get application details
argocd app get sample-saas-app-platform

# Sync application manually
argocd app sync sample-saas-app-platform

# View application resources
argocd app resources sample-saas-app-platform
```

### Multi-Tenant Management

Manage multiple tenants with separate Argo CD applications:

```bash
# Check platform tenant
argocd app get sample-saas-app-platform

# Check analytics tenant
argocd app get sample-saas-app-analytics

# View tenant resources
kubectl get all -n platform
kubectl get all -n analytics
```

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

---

**Built with ❤️ for the CloudNative SaaS community**

