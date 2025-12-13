# GitOps Scripts

Scripts for managing and syncing GitOps configurations.

## Overview

This directory contains utility scripts for GitOps operations. Currently, ECR repository names and other configuration details are managed through GitHub Actions secrets for simplicity and maintainability.

## Configuration Management

### ECR Repository Names

ECR repository names are stored in GitHub Actions secrets in the `Sample-saas-app` repository:

- `ECR_BACKEND_REPO` - Backend ECR repository name
- `ECR_FRONTEND_REPO` - Frontend ECR repository name

The CD pipeline in `Sample-saas-app` uses these secrets to:
1. Construct full ECR image paths
2. Update kustomization files in the GitOps repository
3. Deploy with the correct image references

### Getting ECR Repository Names

To get the ECR repository names from Terraform:

```bash
# Navigate to infrastructure directory
cd cloudnative-saas-eks/examples/dev-environment/infrastructure

# Get repository names
terraform output ecr_backend_repository_name
terraform output ecr_frontend_repository_name

# Or get full URLs
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url
```

Then add these values as secrets in the `Sample-saas-app` GitHub repository.

### Benefits of Using Secrets

✅ **Simple**: Easy to configure and maintain  
✅ **Secure**: Secrets are encrypted and access-controlled  
✅ **Flexible**: Can be updated without code changes  
✅ **No Dependencies**: Doesn't require S3 access or Terraform state parsing  
✅ **Fast**: No need to download and parse Terraform state files  

## Future Scripts

Additional utility scripts can be added here as needed for:
- Environment-specific configuration management
- Bulk updates to kustomization files
- Validation and testing scripts

