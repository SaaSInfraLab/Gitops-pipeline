# Sample SaaS App - GitOps Configuration

This directory contains the GitOps configuration for the Sample SaaS Application deployment.

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
│   │   └── kustomization.yaml
│   └── analytics/           # Analytics tenant overlay
│       ├── namespace.yaml
│       └── kustomization.yaml
```

## Deployment

### Platform Tenant

Deploys to the `platform` namespace with:
- AWS Secrets Manager integration (IRSA)
- Secret sync job for database credentials
- Full resource limits

### Analytics Tenant

Deploys to the `analytics` namespace with:
- ConfigMap-based configuration
- Reduced resource limits
- Shared database credentials

## Image Updates

Images are automatically updated via CI/CD pipeline:

1. **Sample-saas-app CI** builds and pushes images to ECR
2. **CD workflow** updates this GitOps repository with new image tags
3. **Flux CD** detects Git changes and automatically deploys

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

### Environment Variables

Backend environment variables are configured in deployment manifests:
- Database connection (from secrets)
- JWT configuration
- Resource limits

### Secrets

- **Platform**: Uses AWS Secrets Manager via IRSA
- **Analytics**: Uses Kubernetes secrets (created by Terraform)

## Flux Integration

This application is managed by Flux CD. Changes to this directory are automatically synced to the cluster.

### Sync Status

```bash
# Check Flux sync status
flux get kustomizations sample-saas-app

# View sync events
flux events --kind Kustomization --name sample-saas-app
```

### Manual Sync

```bash
# Force immediate sync
flux reconcile kustomization sample-saas-app
```

## Troubleshooting

### Images Not Updating

1. Check if CI/CD updated the GitOps repo:
   ```bash
   git log --oneline apps/sample-saas-app/
   ```

2. Check Flux sync status:
   ```bash
   flux get kustomizations
   ```

3. Check image tags in cluster:
   ```bash
   kubectl get deployment backend -n platform -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

### Deployment Issues

1. Check Flux logs:
   ```bash
   kubectl logs -n flux-system -l app=kustomize-controller
   ```

2. Check application pods:
   ```bash
   kubectl get pods -n platform
   kubectl get pods -n analytics
   ```

## Related Documentation

- [Flux GitOps Pipeline README](../../README.md)
- [Integration Guide](../../docs/integration-guide.md)
- [Sample-saas-app Repository](https://github.com/SaaSInfraLab/Sample-saas-app)

