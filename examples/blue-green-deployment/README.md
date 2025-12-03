# Blue-Green Deployment Example

This example demonstrates a blue-green deployment strategy using Flux CD and Kustomize.

## Overview

Blue-green deployment maintains two identical production environments (blue and green). At any time, only one environment is live. When deploying a new version, it's deployed to the inactive environment. After testing, traffic is switched to the new environment.

## Structure

```
blue-green-deployment/
├── README.md
├── base/                    # Base application configuration
├── blue/                    # Blue environment overlay
└── green/                   # Green environment overlay
```

## Implementation

### Base Configuration

The base contains the common application configuration shared by both blue and green environments.

### Blue Environment

- Namespace: `sample-saas-app-blue`
- Service: Routes traffic to blue pods
- Labels: `version: blue`

### Green Environment

- Namespace: `sample-saas-app-green`
- Service: Routes traffic to green pods
- Labels: `version: green`

## Deployment Process

1. **Deploy to inactive environment** (e.g., green)
2. **Test the new deployment**
3. **Switch traffic** by updating the main service selector
4. **Monitor** the new environment
5. **Cleanup** the old environment after verification

## Usage

```bash
# Deploy blue environment
kubectl apply -k blue-green-deployment/blue

# Deploy green environment
kubectl apply -k blue-green-deployment/green

# Switch traffic to green
kubectl patch service main-service -p '{"spec":{"selector":{"version":"green"}}}'
```

## Flux Integration

Configure Flux to manage blue-green deployments:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: blue-green-app
spec:
  interval: 5m0s
  path: ./examples/blue-green-deployment/blue
  prune: true
```

