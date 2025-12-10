# Infrastructure Application

## Overview

The `infrastructure` Argo CD application manages cluster-wide infrastructure resources that are shared across all tenants and applications.

## What It Deploys

### 1. Namespaces (`infrastructure/namespaces/`)

Creates and manages tenant namespaces:
- **platform** - Platform tenant namespace
- **analytics** - Analytics tenant namespace  
- **data** - Data processing tenant namespace
- **monitoring** - Monitoring stack namespace

Each namespace includes:
- Proper labels for tenant identification
- Environment labels (dev, staging, prod)
- Argo CD management labels

### 2. RBAC (`infrastructure/rbac/`)

Role-Based Access Control resources:
- Service accounts for applications
- Roles and RoleBindings for namespace-scoped permissions
- ClusterRoles and ClusterRoleBindings for cluster-wide permissions

**Note**: Currently empty - add your RBAC resources here as needed.

### 3. Network Policies (`infrastructure/network-policies/`)

Network security policies:
- **default-deny-all** - Denies all ingress and egress traffic by default
- Applied to platform, analytics, and data namespaces
- Ensures zero-trust network model

## Architecture

```
infrastructure/
├── namespaces/
│   ├── platform.yaml      # Platform tenant namespace
│   ├── analytics.yaml      # Analytics tenant namespace
│   ├── data.yaml          # Data tenant namespace
│   ├── monitoring.yaml     # Monitoring namespace
│   └── kustomization.yaml # Namespace resources
├── rbac/
│   └── kustomization.yaml # RBAC resources (add your RBAC here)
└── network-policies/
    ├── default-deny.yaml  # Default deny network policies
    └── kustomization.yaml # Network policy resources
```

## Deployment

The infrastructure application is managed by Argo CD:

```bash
# View application status
kubectl get application infrastructure -n argocd

# Check synced resources
kubectl get all -n platform
kubectl get all -n analytics
kubectl get all -n data
kubectl get all -n monitoring

# Check network policies
kubectl get networkpolicies --all-namespaces
```

## Adding Resources

### Add a New Namespace

1. Create `infrastructure/namespaces/new-tenant.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: new-tenant
  labels:
    tenant: new-tenant
    managed-by: argocd
    environment: dev
```

2. Add to `infrastructure/namespaces/kustomization.yaml`:
```yaml
resources:
  - new-tenant.yaml
```

3. Commit and push - Argo CD will automatically sync

### Add Network Policies

1. Create `infrastructure/network-policies/new-policy.yaml`
2. Add to `infrastructure/network-policies/kustomization.yaml`
3. Commit and push

### Add RBAC Resources

1. Create your Role/ClusterRole resources in `infrastructure/rbac/`
2. Add to `infrastructure/rbac/kustomization.yaml`
3. Commit and push

## Why Separate from Applications?

Infrastructure resources are separated because they:
- Apply cluster-wide or across multiple tenants
- Need to be deployed before applications
- Have different lifecycle management
- Require different access controls

## Troubleshooting

### Namespace Not Created

```bash
# Check Argo CD application status
kubectl describe application infrastructure -n argocd

# Check for sync errors
argocd app get infrastructure
```

### Network Policies Blocking Traffic

Network policies are restrictive by default. You may need to:
1. Add allow rules for specific traffic
2. Check if pods can communicate within the same namespace
3. Verify network policy selectors match pod labels

### RBAC Issues

```bash
# Check service account permissions
kubectl describe role <role-name> -n <namespace>
kubectl describe rolebinding <binding-name> -n <namespace>
```

