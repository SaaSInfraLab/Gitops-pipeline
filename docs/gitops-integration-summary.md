# GitOps Integration Summary

Complete overview of the GitOps integration between Sample-saas-app and flux-gitops-pipeline.

## Architecture

```
┌─────────────────────────────────────┐
│  Sample-saas-app Repository          │
│  ┌────────────────────────────────┐ │
│  │ CI Pipeline                     │ │
│  │ - Run tests                    │ │
│  │ - Build Docker images           │ │
│  │ - Push to ECR                   │ │
│  └──────────────┬──────────────────┘ │
│                 │                     │
│  ┌──────────────▼──────────────────┐ │
│  │ CD Pipeline                     │ │
│  │ - Build images                  │ │
│  │ - Push to ECR                   │ │
│  │ - Update GitOps repo            │ │
│  └──────────────┬──────────────────┘ │
└─────────────────┼─────────────────────┘
                  │
                  │ (Git commit with new image tags)
                  ▼
┌─────────────────────────────────────┐
│  flux-gitops-pipeline Repository     │
│  ┌────────────────────────────────┐ │
│  │ Git Repository                  │ │
│  │ - apps/sample-saas-app/         │ │
│  │   - base/                       │ │
│  │   - overlays/platform/          │ │
│  │   - overlays/analytics/          │ │
│  └──────────────┬──────────────────┘ │
└─────────────────┼─────────────────────┘
                  │
                  │ (Flux watches Git)
                  ▼
┌─────────────────────────────────────┐
│  Flux CD (EKS Cluster)              │
│  ┌────────────────────────────────┐ │
│  │ Kustomize Controller            │ │
│  │ - Detects Git changes           │ │
│  │ - Syncs manifests               │ │
│  │ - Deploys to cluster            │ │
│  └──────────────┬──────────────────┘ │
└─────────────────┼─────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  Kubernetes Cluster                  │
│  - platform namespace                │
│  - analytics namespace               │
│  - Running pods                      │
└─────────────────────────────────────┘
```

## File Structure

### Sample-saas-app

```
Sample-saas-app/
├── .github/workflows/
│   ├── ci.yml          # CI: Tests, linting
│   └── cd.yml          # CD: Build images, update GitOps repo
├── backend/            # Application code
├── frontend/           # Application code
└── database/           # Migrations
```

### flux-gitops-pipeline

```
flux-gitops-pipeline/
├── apps/sample-saas-app/
│   ├── base/           # Common manifests
│   └── overlays/
│       ├── platform/   # Platform tenant
│       └── analytics/  # Analytics tenant
└── clusters/dev-environment/
    └── apps/sample-saas-app-*/
        └── kustomization.yaml  # Flux Kustomization resources
```

## Workflow Steps

### 1. Developer Workflow

```bash
# Make code changes
git add .
git commit -m "Add new feature"
git push origin main
```

### 2. CI Pipeline (Sample-saas-app)

- Runs automatically on push
- Executes tests
- Validates code quality
- Triggers CD pipeline on success

### 3. CD Pipeline (Sample-saas-app)

**Build Jobs:**
- Builds backend Docker image
- Builds frontend Docker image
- Pushes both to ECR with tags (sha, latest, branch)

**GitOps Update Job:**
- Checks out flux-gitops-pipeline repository
- Updates image tags in Kustomization files:
  - `apps/sample-saas-app/base/kustomization.yaml`
  - `apps/sample-saas-app/overlays/platform/kustomization.yaml`
  - `apps/sample-saas-app/overlays/analytics/kustomization.yaml`
- Commits and pushes changes

### 4. Flux CD Sync

- Flux detects Git repository change
- Kustomize controller syncs manifests
- Deploys updated images to cluster
- Updates pods in platform and analytics namespaces

## Configuration

### Required GitHub Secrets

**Sample-saas-app repository:**
- `AWS_ROLE_ARN` - IAM role for ECR access
- `ECR_BACKEND_REPO` - ECR repository name
- `ECR_FRONTEND_REPO` - ECR repository name
- `GITOPS_REPO_TOKEN` - PAT for flux-gitops-pipeline repo

### Image Tagging Strategy

Images are tagged with:
- **SHA tag**: `sha-<commit-sha>` (unique, traceable)
- **Latest tag**: `latest` (main branch only)
- **Branch tag**: `<branch-name>` (feature branches)

The CD pipeline extracts the SHA tag and updates GitOps manifests.

## Multi-Tenant Deployment

### Platform Tenant

- **Namespace**: `platform`
- **Secrets**: AWS Secrets Manager via IRSA
- **Resources**: Higher limits (500m CPU, 2Gi memory)
- **Features**: Secret sync job, AWS Secrets Manager integration

### Analytics Tenant

- **Namespace**: `analytics`
- **Secrets**: Kubernetes secrets (from Terraform)
- **Resources**: Lower limits (200m CPU, 1Gi memory)
- **Features**: ConfigMap-based configuration

## Verification

### Check CD Pipeline

```bash
# View GitHub Actions
# Sample-saas-app → Actions → CD workflow
```

### Check GitOps Update

```bash
# View Git commits in flux-gitops-pipeline
git log --oneline apps/sample-saas-app/
```

### Check Flux Sync

```bash
# Check Kustomization status
flux get kustomizations sample-saas-app-platform
flux get kustomizations sample-saas-app-analytics

# View sync events
flux events --kind Kustomization
```

### Check Deployment

```bash
# Check pods
kubectl get pods -n platform
kubectl get pods -n analytics

# Check image tags
kubectl get deployment backend -n platform -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Troubleshooting

### CD Pipeline Fails to Update GitOps

1. Check `GITOPS_REPO_TOKEN` secret
2. Verify token has `repo` scope
3. Check workflow logs for Git errors

### Flux Not Syncing

1. Check GitRepository status:
   ```bash
   flux get sources git
   ```

2. Check Kustomization status:
   ```bash
   flux get kustomizations
   ```

3. View Flux logs:
   ```bash
   kubectl logs -n flux-system -l app=kustomize-controller
   ```

### Images Not Updating

1. Verify CD pipeline updated GitOps repo
2. Check image tags in Kustomization files
3. Force Flux sync:
   ```bash
   flux reconcile kustomization sample-saas-app-platform
   ```

## Benefits

✅ **Separation of Concerns**: Application code separate from deployment config
✅ **Audit Trail**: All deployments tracked in Git
✅ **Rollback**: Revert Git commit to rollback
✅ **Consistency**: Same process for all environments
✅ **Security**: No kubectl access needed in CI/CD
✅ **Developer Experience**: Developers just push code

## Next Steps

- Configure monitoring integration
- Set up alerting for deployments
- Implement blue-green/canary strategies
- Add production environment overlays

