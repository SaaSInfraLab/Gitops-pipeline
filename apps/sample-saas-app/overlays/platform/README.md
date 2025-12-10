# Platform Tenant Overlay

This overlay configures the **platform** tenant deployment with AWS Secrets Manager integration.

## Features

- ✅ AWS Secrets Manager integration for RDS credentials
- ✅ Secret sync job to trigger secret mounting
- ✅ Platform-specific namespace
- ✅ Tenant-specific labels and selectors

## Prerequisites

### 1. AWS Secrets Store CSI Driver

Install the AWS Secrets Store CSI driver in your cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/secrets-store-csi-driver.yaml
```

### 2. IAM Role Setup

Create an IAM role `EKSSecretsManagerRole` with:
- Trust relationship allowing your EKS cluster's OIDC provider
- Permissions to read secrets from AWS Secrets Manager

### 3. Configure AWS Secrets Manager Integration

Edit `aws-secrets-manager.yaml` and replace:
- `${AWS_ACCOUNT_ID}` with your AWS account ID
- `${RDS_SECRET_ARN}` with your RDS secret ARN from AWS Secrets Manager

Example:
```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::821368347884:role/EKSSecretsManagerRole
```

```yaml
- objectName: "arn:aws:secretsmanager:us-east-1:821368347884:secret:rds-credentials-xxxxx"
```

### 4. Disable AWS Secrets Manager (Optional)

If you don't want to use AWS Secrets Manager, you can:

1. Remove `aws-secrets-manager.yaml` and `secret-sync-job.yaml` from `kustomization.yaml`
2. Use regular Kubernetes secrets instead (configured in base manifests)

## Deployment

This overlay is automatically deployed by Argo CD when the `sample-saas-app-platform` application is synced.

## Troubleshooting

### Secret Not Mounting

1. Check if AWS Secrets Store CSI driver is installed:
   ```bash
   kubectl get pods -n kube-system | grep secrets-store
   ```

2. Check ServiceAccount annotation:
   ```bash
   kubectl get sa backend-sa -n platform -o yaml
   ```

3. Check SecretProviderClass:
   ```bash
   kubectl get secretproviderclass db-secret-provider -n platform -o yaml
   ```

4. Check secret sync job logs:
   ```bash
   kubectl logs -n platform job/secret-sync-trigger
   ```

### IAM Role Issues

1. Verify role trust relationship includes your EKS OIDC provider
2. Check role permissions include `secretsmanager:GetSecretValue`
3. Verify role ARN matches the ServiceAccount annotation

