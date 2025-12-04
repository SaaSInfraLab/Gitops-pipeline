# Rollback Scenario Example

This example demonstrates how to rollback deployments using Flux CD and Git.

## Overview

Rollback in GitOps is achieved by reverting to a previous Git commit. Flux CD will automatically sync the cluster to match the Git repository state.

## Rollback Strategies

### 1. Git Revert (Recommended)

Revert the problematic commit in Git:

```bash
# Find the commit to revert
git log --oneline

# Revert the commit
git revert <commit-hash>

# Push the revert
git push origin main
```

Flux will automatically detect the change and rollback the deployment.

### 2. Manual Kustomization Update

Temporarily point to a previous commit:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: sample-app
spec:
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/sample-saas-app/overlays/dev
  # Point to previous commit
  # This requires updating the GitRepository ref
```

### 3. Flux CLI Rollback

Use Flux CLI to suspend and resume:

```bash
# Suspend the Kustomization
flux suspend kustomization sample-app

# Make changes manually or revert Git
# ...

# Resume the Kustomization
flux resume kustomization sample-app
```

## Example Rollback Process

### Step 1: Identify the Issue

```bash
# Check current deployment status
kubectl get pods -n sample-saas-app

# Check Flux sync status
flux get kustomizations sample-app

# View recent events
flux events --kind Kustomization --name sample-app
```

### Step 2: Revert in Git

```bash
# Navigate to repository
cd Gitops-pipeline

# Check recent commits
git log --oneline -10

# Revert the problematic commit
git revert HEAD

# Push the revert
git push origin main
```

### Step 3: Verify Rollback

```bash
# Wait for Flux to sync (default interval: 5m)
flux get kustomizations sample-app

# Check if pods are rolling back
kubectl get pods -n sample-saas-app -w

# Verify application health
kubectl get endpoints -n sample-saas-app
```

## Prevention Strategies

1. **Use Kustomize overlays** for environment-specific configs
2. **Test in dev/staging** before production
3. **Use image tags** instead of `latest`
4. **Implement health checks** and readiness probes
5. **Monitor metrics** before and after deployment

## Automated Rollback

Configure Prometheus alerts to trigger rollbacks:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: rollback-alerts
spec:
  groups:
  - name: deployment
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
      for: 5m
      annotations:
        description: "High error rate detected, consider rollback"
```

## Best Practices

1. **Always tag releases** in Git
2. **Keep deployment history** in Git
3. **Use feature flags** for gradual rollouts
4. **Monitor before promoting** to production
5. **Document rollback procedures** for your team

