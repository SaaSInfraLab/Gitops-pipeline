# Troubleshooting Guide

Common issues and solutions when working with Flux GitOps Pipeline.

## Table of Contents

- [Flux Components Not Starting](#flux-components-not-starting)
- [Git Repository Sync Issues](#git-repository-sync-issues)
- [Kustomization Sync Failures](#kustomization-sync-failures)
- [Application Deployment Issues](#application-deployment-issues)
- [Image Update Automation Issues](#image-update-automation-issues)
- [IRSA and AWS Integration Issues](#irsa-and-aws-integration-issues)
- [Network Policy Issues](#network-policy-issues)

## Flux Components Not Starting

### Symptoms

- Pods in `flux-system` namespace are not running
- Pods stuck in `Pending` or `CrashLoopBackOff` state

### Diagnosis

```bash
# Check pod status
kubectl get pods -n flux-system

# Check events
kubectl describe pod -n flux-system <pod-name>

# Check logs
kubectl logs -n flux-system <pod-name>
```

### Solutions

#### Insufficient Resources

```bash
# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl describe pod -n flux-system <pod-name> | grep -A 5 "Requests:"

# Solution: Increase node capacity or adjust resource requests
```

#### RBAC Issues

```bash
# Check service account
kubectl get serviceaccount -n flux-system

# Check cluster role bindings
kubectl get clusterrolebinding | grep flux

# Solution: Re-bootstrap Flux
flux bootstrap github --owner=YOUR_ORG --repository=YOUR_REPO
```

#### Image Pull Errors

```bash
# Check image pull errors
kubectl describe pod -n flux-system <pod-name> | grep -i "pull"

# Solution: Ensure cluster has internet access or configure image pull secrets
```

## Git Repository Sync Issues

### Symptoms

- GitRepository shows `False` ready status
- Error messages about authentication or access

### Diagnosis

```bash
# Check GitRepository status
flux get sources git

# Check detailed status
kubectl describe gitrepository -n flux-system flux-system

# Check authentication secret
kubectl get secret -n flux-system flux-system -o yaml
```

### Solutions

#### Authentication Failures

**GitHub Token Issues:**

```bash
# Create or update GitHub token secret
kubectl create secret generic flux-system \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_TOKEN \
  -n flux-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Update GitRepository to use token
flux create source git flux-system \
  --url=https://github.com/YOUR_ORG/YOUR_REPO \
  --branch=main \
  --secret-ref=flux-system
```

**SSH Key Issues:**

```bash
# Generate SSH key
ssh-keygen -t ecdsa -b 521 -C "flux" -f flux-key

# Add public key to GitHub/GitLab
cat flux-key.pub

# Create secret with private key
kubectl create secret generic flux-system \
  --from-file=identity=flux-key \
  -n flux-system

# Update GitRepository
flux create source git flux-system \
  --url=git@github.com:YOUR_ORG/YOUR_REPO.git \
  --branch=main \
  --secret-ref=flux-system
```

#### Repository Not Found

```bash
# Verify repository URL
flux get sources git flux-system

# Check repository access
git ls-remote https://github.com/YOUR_ORG/YOUR_REPO

# Solution: Update GitRepository URL
flux create source git flux-system \
  --url=https://github.com/YOUR_ORG/YOUR_REPO \
  --branch=main
```

## Kustomization Sync Failures

### Symptoms

- Kustomization shows `False` ready status
- Error messages about path or resources

### Diagnosis

```bash
# Check Kustomization status
flux get kustomizations

# Check detailed status
kubectl describe kustomization -n flux-system <name>

# Check events
flux events --kind Kustomization --name <name>
```

### Solutions

#### Path Not Found

```bash
# Verify path exists in Git repository
git ls-tree -r HEAD --name-only | grep <path>

# Solution: Update Kustomization path
flux create kustomization <name> \
  --source=flux-system \
  --path="./correct/path" \
  --prune=true
```

#### Resource Validation Errors

```bash
# Check validation errors
kubectl describe kustomization -n flux-system <name> | grep -i "validation"

# Solution: Fix YAML syntax or resource definitions
# Use dry-run to validate
kubectl apply --dry-run=client -k <path>
```

#### Dependency Issues

```bash
# Check if dependencies are ready
flux get sources git
flux get kustomizations

# Solution: Ensure GitRepository is ready before Kustomization
flux reconcile source git flux-system
flux reconcile kustomization <name>
```

## Application Deployment Issues

### Symptoms

- Application pods not starting
- Services not accessible
- ConfigMap/Secret not found errors

### Diagnosis

```bash
# Check deployment status
kubectl get deployments -n <namespace>

# Check pod status
kubectl get pods -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n <namespace> <pod-name>
```

### Solutions

#### Image Pull Errors

```bash
# Check image pull secrets
kubectl get secrets -n <namespace>

# For ECR, create image pull secret
aws ecr get-login-password --region us-east-1 | \
  kubectl create secret docker-registry ecr-secret \
    --docker-server=YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region us-east-1) \
    -n <namespace>
```

#### Missing Secrets/ConfigMaps

```bash
# Check if secrets exist
kubectl get secrets -n <namespace>

# Check if ConfigMaps exist
kubectl get configmaps -n <namespace>

# Solution: Ensure secrets are created before deployment
# Or use init containers to wait for secrets
```

#### Resource Quota Exceeded

```bash
# Check quotas
kubectl get quota -n <namespace>

# Check resource usage
kubectl describe quota -n <namespace>

# Solution: Reduce resource requests or increase quota
```

## Image Update Automation Issues

### Symptoms

- ImageRepository not scanning
- ImagePolicy not updating
- ImageUpdateAutomation not committing

### Diagnosis

```bash
# Check ImageRepository status
flux get images repository

# Check ImagePolicy status
flux get images policy

# Check ImageUpdateAutomation status
flux get images update
```

### Solutions

#### ImageRepository Not Scanning

```bash
# Check authentication
kubectl describe imagerepository -n flux-system <name>

# For ECR, ensure IRSA is configured
# Check service account
kubectl get serviceaccount -n flux-system image-reflector-controller

# Solution: Configure IRSA for ECR access
```

#### ImagePolicy Not Matching

```bash
# Check policy rules
flux get images policy <name> -o yaml

# Test semver matching
# Solution: Adjust policy selectors
flux create image policy <name> \
  --image-ref=<repository> \
  --select-semver=">=1.0.0"
```

## IRSA and AWS Integration Issues

### Symptoms

- Pods cannot access AWS services
- Secrets Manager sync failures
- ECR image pull failures

### Diagnosis

```bash
# Check service account annotations
kubectl get serviceaccount -n <namespace> <name> -o yaml

# Test IRSA from pod
kubectl run test-pod \
  --image=amazon/aws-cli \
  --serviceaccount=<service-account> \
  -n <namespace> \
  --rm -it -- \
  aws sts get-caller-identity
```

### Solutions

#### Missing IRSA Annotation

```bash
# Add IRSA annotation to service account
kubectl annotate serviceaccount <name> \
  -n <namespace> \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
```

#### IAM Role Trust Policy Issues

```bash
# Verify OIDC provider
aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer"

# Check IAM role trust policy
aws iam get-role --role-name ROLE_NAME --query "Role.AssumeRolePolicyDocument"

# Solution: Update trust policy to include OIDC provider
```

#### Secrets Manager Access

```bash
# Check IAM policy permissions
aws iam get-role-policy \
  --role-name EKSSecretsManagerRole \
  --policy-name SecretsManagerAccess

# Solution: Ensure policy allows secretsmanager:GetSecretValue
```

## Network Policy Issues

### Symptoms

- Pods cannot communicate
- Services not accessible
- DNS resolution failures

### Diagnosis

```bash
# Check network policies
kubectl get networkpolicies -n <namespace>

# Check pod connectivity
kubectl run test-pod --image=busybox -n <namespace> --rm -it -- wget -O- <service-url>

# Check DNS
kubectl run test-pod --image=busybox -n <namespace> --rm -it -- nslookup <service-name>
```

### Solutions

#### Overly Restrictive Policies

```bash
# Check network policy rules
kubectl get networkpolicy -n <namespace> -o yaml

# Solution: Update network policy to allow required traffic
# Ensure DNS (port 53) and service ports are allowed
```

#### Missing Egress Rules

```bash
# Add egress rules for required services
# Example: Allow egress to RDS (port 5432)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-rds
spec:
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 5432
```

## Getting Help

### Useful Commands

```bash
# Check all Flux resources
flux get all

# Check cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check resource status
kubectl get all -n <namespace>

# View detailed resource information
kubectl describe <resource-type> <resource-name> -n <namespace>
```

### Additional Resources

- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Flux CD Troubleshooting](https://fluxcd.io/docs/troubleshooting/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [GitHub Issues](https://github.com/SaaSInfraLab/flux-gitops-pipeline/issues)

### Log Collection

```bash
# Collect logs for troubleshooting
kubectl logs -n flux-system -l app=source-controller > source-controller.log
kubectl logs -n flux-system -l app=kustomize-controller > kustomize-controller.log
kubectl logs -n flux-system -l app=helm-controller > helm-controller.log

# Export resource definitions
kubectl get all -n flux-system -o yaml > flux-resources.yaml
```

