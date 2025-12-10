# GitHub Secrets Setup Guide for GitOps Pipeline

This repository requires GitHub Actions secrets to sync ECR repository names to kustomization files.

## Required Secrets

Configure these secrets in this repository:
**Settings → Secrets and variables → Actions → New repository secret**

### 1. AWS_ROLE_ARN

**Description**: IAM role ARN for GitHub Actions to access AWS services (ECR, S3)

**How to get**:
```bash
# From Terraform outputs
cd cloudnative-saas-eks/examples/dev-environment/infrastructure
terraform output

# Or from AWS Console
# IAM → Roles → Find your GitHub Actions role → Copy ARN
```

**Example**: `arn:aws:iam::821368347884:role/github-actions-ecr-eks-role`

**Required permissions**:
- ECR: Read repository information
- S3: Read Terraform state (optional, if needed)
- STS: Get caller identity (to get AWS account ID)

---

### 2. ECR_BACKEND_REPO

**Description**: ECR repository name for backend (just the name, not the full path)

**How to get**:
```bash
# From Terraform outputs
cd cloudnative-saas-eks/examples/dev-environment/infrastructure
terraform output ecr_backend_repository_name

# Or extract from full URL
terraform output ecr_backend_repository_url
# Example output: 821368347884.dkr.ecr.us-east-1.amazonaws.com/saas-infra-lab-dev-backend
# Extract: saas-infra-lab-dev-backend
```

**Example**: `saas-infra-lab-dev-backend`

**Note**: Only the repository name, not the full ECR URL

---

### 3. ECR_FRONTEND_REPO

**Description**: ECR repository name for frontend (just the name, not the full path)

**How to get**:
```bash
# From Terraform outputs
cd cloudnative-saas-eks/examples/dev-environment/infrastructure
terraform output ecr_frontend_repository_name

# Or extract from full URL
terraform output ecr_frontend_repository_url
# Example output: 821368347884.dkr.ecr.us-east-1.amazonaws.com/saas-infra-lab-dev-frontend
# Extract: saas-infra-lab-dev-frontend
```

**Example**: `saas-infra-lab-dev-frontend`

**Note**: Only the repository name, not the full ECR URL

---

## How It Works

The `.github/workflows/sync-ecr-repositories.yml` workflow:

1. **Runs automatically**:
   - Daily at 3 AM UTC (scheduled)
   - On manual trigger (workflow_dispatch)
   - When the workflow file is updated

2. **Reads secrets**:
   - `ECR_BACKEND_REPO`
   - `ECR_FRONTEND_REPO`
   - `AWS_ROLE_ARN`

3. **Updates kustomization files**:
   - Constructs full ECR image paths: `{AWS_ACCOUNT}.dkr.ecr.{REGION}.amazonaws.com/{REPO_NAME}`
   - Updates all kustomization files (base, platform, analytics overlays)
   - Preserves existing image tags (only updates repository names)

4. **Commits and pushes**:
   - Commits changes to `develop` branch
   - Argo CD automatically syncs the changes

## Quick Setup Checklist

- [ ] Get `AWS_ROLE_ARN` from Terraform outputs or AWS Console
- [ ] Get `ECR_BACKEND_REPO` from Terraform: `terraform output ecr_backend_repository_name`
- [ ] Get `ECR_FRONTEND_REPO` from Terraform: `terraform output ecr_frontend_repository_name`
- [ ] Add all 3 secrets to this repository (Gitops-pipeline)
- [ ] Run the workflow manually to test: Actions → "Sync ECR Repository Names" → Run workflow

## Manual Trigger

To manually sync ECR repository names:

1. Go to **Actions** tab in this repository
2. Select **"Sync ECR Repository Names"** workflow
3. Click **"Run workflow"**
4. Select branch: `develop`
5. Click **"Run workflow"**

## Integration with CD Pipeline

The CD pipeline in `Sample-saas-app` will:
1. Build Docker images
2. Push to ECR
3. Update **image tags** in kustomization files

The ECR repository names are managed by this workflow, so the CD pipeline only needs to update tags.

## Troubleshooting

### Secret Not Found

- Verify secret names match exactly (case-sensitive)
- Check secrets are added to this repository (Gitops-pipeline)
- Ensure secrets are under "Actions" secrets, not "Dependabot"

### AWS Access Denied

- Verify `AWS_ROLE_ARN` is correct
- Check IAM role has required permissions
- Verify role trust relationship allows GitHub Actions

### No Changes Committed

- This is normal if repository names are already correct
- Check workflow logs to see what was updated
- Verify secrets contain the correct repository names

