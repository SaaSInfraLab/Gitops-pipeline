# Sample SaaS App - GitOps Configuration

This directory contains the GitOps configuration for the Sample SaaS Application deployment managed by Argo CD.

## Structure

```
apps/sample-saas-app/
├── base/                    # Base manifests (common for all tenants)
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── init-db-job.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── platform/            # Platform tenant overlay
│   │   ├── namespace.yaml
│   │   ├── aws-secrets-manager.yaml
│   │   ├── secret-sync-job.yaml
│   │   ├── kustomization.yaml
│   │   └── README.md
│   └── analytics/           # Analytics tenant overlay
│       ├── namespace.yaml
│       └── kustomization.yaml
```

## Deployment

### Platform Tenant

Deploys to the `platform` namespace with:
- ✅ AWS Secrets Manager integration (IRSA) for RDS credentials
- ✅ Secret sync job to trigger secret mounting
- ✅ Full resource limits
- ✅ Production-ready configuration

**Prerequisites:**
- AWS Secrets Store CSI driver installed
- IAM role `EKSSecretsManagerRole` with Secrets Manager permissions
- RDS secret stored in AWS Secrets Manager

See [platform/README.md](overlays/platform/README.md) for detailed setup instructions.

### Analytics Tenant

Deploys to the `analytics` namespace with:
- ✅ ConfigMap-based configuration
- ✅ Reduced resource limits (optimized for analytics workloads)
- ✅ Shared database credentials via Kubernetes secrets
- ✅ Metrics enabled for monitoring

## Image Updates

Images are automatically updated via CI/CD pipeline:

1. **Sample-saas-app CI** builds and pushes images to ECR
2. **CD workflow** updates this GitOps repository with new image tags
3. **Argo CD** detects Git changes and automatically deploys

### How It Works

The CD pipeline in `Sample-saas-app`:
- Builds Docker images (backend + frontend)
- Pushes to ECR with tags (SHA, latest, branch name)
- Updates image tags in kustomization files:
  - `base/kustomization.yaml`
  - `overlays/platform/kustomization.yaml`
  - `overlays/analytics/kustomization.yaml`
- Commits and pushes changes to `develop` branch
- Argo CD automatically syncs and deploys

### Manual Image Update

To manually update image tags:

```bash
# Update base kustomization
yq eval '.images[0].newTag = "v1.2.3"' -i base/kustomization.yaml

# Or update specific overlay
yq eval '.images[0].newTag = "v1.2.3"' -i overlays/platform/kustomization.yaml
```

## Configuration

### Image Tags

Image tags are managed in Kustomization files:
- `base/kustomization.yaml` - Base image configuration
- `overlays/platform/kustomization.yaml` - Platform-specific images
- `overlays/analytics/kustomization.yaml` - Analytics-specific images

**Note:** ECR repository names are managed by the `sync-ecr-repositories` workflow in this repository. The CD pipeline only updates tags.

### Environment Variables

Backend environment variables are configured in deployment manifests:
- Database connection (from secrets)
- JWT configuration
- Resource limits
- Tenant-specific configurations

### Secrets

- **Platform**: Uses AWS Secrets Manager via IRSA (IAM Roles for Service Accounts)
  - ServiceAccount: `backend-sa` with IAM role annotation
  - SecretProviderClass: `db-secret-provider` syncs RDS credentials
  - Secret: `db-credentials` created automatically

- **Analytics**: Uses Kubernetes secrets (created by Terraform)
  - Secret: `postgresql-secret` with database credentials
  - ConfigMap: `backend-config` with database connection info

## Argo CD Integration

This application is managed by Argo CD. Changes to this directory are automatically synced to the cluster.

### Applications

Two Argo CD applications manage the deployments:
- `sample-saas-app-platform` - Deploys platform tenant
- `sample-saas-app-analytics` - Deploys analytics tenant

### Sync Status

```bash
# Check Argo CD application status
kubectl get applications -n argocd | grep sample-saas-app

# View detailed status
argocd app get sample-saas-app-platform
argocd app get sample-saas-app-analytics

# Check sync history
argocd app history sample-saas-app-platform
```

### Manual Sync

```bash
# Force immediate sync
argocd app sync sample-saas-app-platform
argocd app sync sample-saas-app-analytics

# Or via kubectl
kubectl patch application sample-saas-app-platform -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"develop"}}}'
```

## Platform vs Analytics Differences

| Feature | Platform | Analytics |
|---------|----------|-----------|
| **Secrets** | AWS Secrets Manager (IRSA) | Kubernetes Secrets |
| **Service Account** | `backend-sa` with IAM role | Default service account |
| **Resource Limits** | Full (requests: 500m/512Mi) | Reduced (requests: 50m/256Mi) |
| **Database Config** | From AWS Secrets Manager | From ConfigMap + Secret |
| **Metrics** | Standard | Enabled with reduced memory |
| **Use Case** | Production workloads | Analytics/Reporting workloads |

## Troubleshooting

### Images Not Updating

1. Check if CD pipeline updated the GitOps repo:
   ```bash
   git log --oneline apps/sample-saas-app/
   ```

2. Check Argo CD sync status:
   ```bash
   argocd app get sample-saas-app-platform
   ```

3. Check image tags in cluster:
   ```bash
   kubectl get deployment backend -n platform -o jsonpath='{.spec.template.spec.containers[0].image}'
   kubectl get deployment backend -n analytics -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

### Platform Deployment Issues

1. Check AWS Secrets Manager integration:
   ```bash
   # Check ServiceAccount
   kubectl get sa backend-sa -n platform -o yaml
   
   # Check SecretProviderClass
   kubectl get secretproviderclass db-secret-provider -n platform -o yaml
   
   # Check secret sync job
   kubectl get jobs -n platform
   kubectl logs -n platform job/secret-sync-trigger
   ```

2. Check application pods:
   ```bash
   kubectl get pods -n platform
   kubectl describe pod <pod-name> -n platform
   kubectl logs <pod-name> -n platform
   ```

3. Check Argo CD sync errors:
   ```bash
   argocd app get sample-saas-app-platform
   kubectl describe application sample-saas-app-platform -n argocd
   ```

### Analytics Deployment Issues

1. Check secrets and configmaps:
   ```bash
   kubectl get secrets -n analytics
   kubectl get configmaps -n analytics
   ```

2. Check application pods:
   ```bash
   kubectl get pods -n analytics
   kubectl describe pod <pod-name> -n analytics
   kubectl logs <pod-name> -n analytics
   ```

## Related Documentation

- [GitOps Pipeline README](../../README.md)
- [Platform Overlay README](overlays/platform/README.md)
- [Infrastructure README](../../INFRASTRUCTURE_README.md)
- [Monitoring Stack README](../../MONITORING_STACK_README.md)
- [Sample-saas-app Repository](https://github.com/SaaSInfraLab/Sample-saas-app)
