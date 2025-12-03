# Integration Guide: Flux GitOps with cloudnative-saas-eks

This guide explains how to integrate Flux GitOps Pipeline with the existing cloudnative-saas-eks infrastructure.

## Overview

The integration connects:
- **cloudnative-saas-eks**: Terraform-based EKS infrastructure
- **flux-gitops-pipeline**: GitOps deployment automation
- **Sample-saas-app**: Multi-tenant SaaS application

## Architecture

```
┌─────────────────────────────────────┐
│  cloudnative-saas-eks (Terraform)   │
│  - EKS Cluster                      │
│  - VPC, Subnets                     │
│  - IAM Roles (IRSA)                 │
│  - RDS Database                     │
│  - Secrets Manager                  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  flux-gitops-pipeline (GitOps)      │
│  - Flux CD Components               │
│  - Application Definitions          │
│  - Infrastructure Configs          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Sample-saas-app (Kubernetes)       │
│  - Frontend/Backend Pods            │
│  - Services                          │
│  - ConfigMaps/Secrets               │
└─────────────────────────────────────┘
```

## Prerequisites

1. **EKS Cluster** deployed via cloudnative-saas-eks
2. **kubectl** configured to access the cluster
3. **Git repository** for Flux GitOps
4. **AWS credentials** configured

## Integration Steps

### Step 1: Deploy EKS Infrastructure

Deploy the EKS cluster using cloudnative-saas-eks:

```bash
cd cloudnative-saas-eks/examples/dev-environment/infrastructure
terraform init
terraform plan -var-file="../infrastructure.tfvars"
terraform apply -var-file="../infrastructure.tfvars"
```

### Step 2: Configure kubectl

```bash
# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw aws_region)

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Verify access
kubectl get nodes
```

### Step 3: Bootstrap Flux CD

```bash
cd flux-gitops-pipeline/bootstrap
./install.sh
```

Or manually:

```bash
flux bootstrap github \
  --owner=SaaSInfraLab \
  --repository=flux-gitops-pipeline \
  --branch=main \
  --path=clusters/dev-environment
```

### Step 4: Configure Namespaces

The integration uses existing namespaces from Terraform:

- `platform` - Main application namespace
- `analytics` - Analytics tenant namespace
- `data` - Data team namespace

Flux will manage deployments in these namespaces:

```yaml
# clusters/dev-environment/infrastructure/kustomization.yaml
resources:
  - ../../../infrastructure/namespaces
```

### Step 5: Configure AWS Secrets Manager Integration

The sample-saas-app uses AWS Secrets Manager for database credentials via IRSA.

#### Create IRSA Role for Flux

```bash
# Get cluster OIDC issuer URL
aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text

# Create IAM role for Flux (if not exists)
# Use the existing EKSSecretsManagerRole or create a new one
```

#### Update Service Account

The backend deployment uses a service account with IRSA:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: platform
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/EKSSecretsManagerRole
```

#### Configure SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: db-secret-provider
  namespace: platform
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:RDS_SECRET_NAME"
        objectType: "secretsmanager"
```

### Step 6: Deploy Sample SaaS App

```bash
# Create Kustomization for sample-saas-app
flux create kustomization sample-saas-app \
  --source=flux-system \
  --path="./apps/sample-saas-app/overlays/dev" \
  --prune=true \
  --interval=5m \
  --target-namespace=platform
```

Or apply the existing configuration:

```bash
kubectl apply -f clusters/dev-environment/apps/sample-saas-app/kustomization.yaml
```

### Step 7: Update Image References

Update ECR image references in Kustomization overlays:

```yaml
# apps/sample-saas-app/overlays/dev/kustomization.yaml
images:
  - name: task-management-backend
    newName: YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/saas-infra-lab-dev-backend
    newTag: latest
```

## Multi-Tenant Integration

### Namespace Management

Flux manages deployments across multiple tenant namespaces:

```yaml
# Deploy to platform namespace
flux create kustomization sample-saas-app-platform \
  --source=flux-system \
  --path="./apps/sample-saas-app/overlays/dev" \
  --target-namespace=platform

# Deploy to analytics namespace
flux create kustomization sample-saas-app-analytics \
  --source=flux-system \
  --path="./apps/sample-saas-app/overlays/dev" \
  --target-namespace=analytics
```

### Resource Quotas

Resource quotas are managed by Terraform in cloudnative-saas-eks. Flux deployments respect these quotas:

```bash
# Check quotas
kubectl get quota -n platform
kubectl get quota -n analytics
```

### Network Policies

Network policies are managed via Flux:

```bash
# Apply network policies
kubectl apply -k infrastructure/network-policies
```

## Monitoring Integration

### Deploy Monitoring Stack

The monitoring stack can be deployed via Flux:

```bash
# Create HelmRepository for prometheus-community
flux create source helm prometheus-community \
  --url=https://prometheus-community.github.io/helm-charts

# Create HelmRelease for kube-prometheus-stack
flux create helmrelease monitoring-stack \
  --source=HelmRepository/prometheus-community \
  --chart=kube-prometheus-stack \
  --namespace=monitoring \
  --values=monitoring-stack/helm/kube-prometheus-stack/values.yaml
```

See [monitoring-stack](../monitoring-stack) repository for details.

## CI/CD Integration

### GitHub Actions

Example workflow for automated deployments:

```yaml
name: Deploy via Flux

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ secrets.CLUSTER_NAME }} --region ${{ secrets.AWS_REGION }}
      
      - name: Trigger Flux sync
        run: |
          flux reconcile source git flux-system
          flux reconcile kustomization sample-saas-app
```

## Troubleshooting

### IRSA Issues

```bash
# Verify OIDC provider
aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer"

# Check service account
kubectl get serviceaccount backend-sa -n platform -o yaml

# Test IRSA
kubectl run test-pod --image=amazon/aws-cli --serviceaccount=backend-sa -n platform --rm -it -- aws sts get-caller-identity
```

### Secret Sync Issues

```bash
# Check SecretProviderClass
kubectl get secretproviderclass -n platform

# Check secrets
kubectl get secrets -n platform

# Check CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

### Namespace Conflicts

If namespaces are created by both Terraform and Flux:

```bash
# Check namespace labels
kubectl get namespace platform -o yaml

# Add label to prevent conflicts
kubectl label namespace platform managed-by=flux
```

## Best Practices

1. **Separate Concerns**: Terraform manages infrastructure, Flux manages applications
2. **Use IRSA**: Always use IAM Roles for Service Accounts for AWS access
3. **Namespace Labels**: Label namespaces to identify management tool
4. **Resource Quotas**: Respect quotas set by Terraform
5. **Secrets Management**: Use AWS Secrets Manager via IRSA
6. **Image Automation**: Configure image update automation for CI/CD

## Next Steps

- Configure [monitoring stack](../monitoring-stack) integration
- Set up [image automation](https://fluxcd.io/docs/components/image/)
- Implement [deployment strategies](../examples/)
- Configure [alerting](../monitoring-stack/docs/alerting-guide.md)

