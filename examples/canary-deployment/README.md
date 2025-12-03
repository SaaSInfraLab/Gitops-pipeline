# Canary Deployment Example

This example demonstrates a canary deployment strategy using Flux CD and Argo Rollouts (or native Kubernetes).

## Overview

Canary deployment gradually shifts traffic from the old version to the new version. A small percentage of traffic is routed to the new version initially, and if successful, the percentage is gradually increased.

## Structure

```
canary-deployment/
├── README.md
├── base/                    # Base application configuration
├── stable/                  # Stable version overlay
└── canary/                  # Canary version overlay
```

## Implementation

### Base Configuration

Common configuration for both stable and canary versions.

### Stable Environment

- Namespace: `sample-saas-app`
- Replicas: 90% of traffic
- Labels: `version: stable`

### Canary Environment

- Namespace: `sample-saas-app`
- Replicas: 10% of traffic
- Labels: `version: canary`

## Deployment Process

1. **Deploy canary** with 10% replicas
2. **Monitor** metrics and health
3. **Gradually increase** canary percentage (20%, 50%, 100%)
4. **Promote** canary to stable if successful
5. **Rollback** if issues detected

## Usage

```bash
# Deploy stable version
kubectl apply -k canary-deployment/stable

# Deploy canary version (10% traffic)
kubectl apply -k canary-deployment/canary

# Scale canary to 50% traffic
kubectl scale deployment canary-app --replicas=5

# Promote canary to stable
kubectl delete deployment stable-app
kubectl patch deployment canary-app -p '{"metadata":{"labels":{"version":"stable"}}}'
```

## Flux Integration

Configure Flux to manage canary deployments:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: canary-app
spec:
  interval: 5m0s
  path: ./examples/canary-deployment/canary
  prune: true
```

## Advanced: Using Argo Rollouts

For more advanced canary deployments, consider using Argo Rollouts with Flux:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: sample-app
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {}
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 100
```

