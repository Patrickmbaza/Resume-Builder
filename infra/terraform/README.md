# Terraform: ECR + App Runner

This stack is intended to be operated primarily by GitHub Actions, not by ad hoc local Terraform runs.

It creates:
- Amazon ECR repository
- ECR lifecycle policy
- IAM role for App Runner to pull from private ECR
- App Runner autoscaling configuration
- App Runner service

## Source of Truth

The intended control path is:
- `.github/workflows/infra-provision.yml`
- `.github/workflows/app-deploy.yml`
- `.github/workflows/infra-destroy.yml`

Those workflows use a shared remote backend so Terraform state is centralized and consistent.

## Tracked Configuration

Production variables are committed in:
- `environments/production.tfvars`

This keeps non-secret infrastructure settings versioned in git.

## Remote Backend

This module expects an S3 backend configured at runtime:
- S3 bucket for Terraform state
- DynamoDB table for state locking

The workflows pass these values through backend config:
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `TF_STATE_KEY`
- `AWS_REGION`

## GitHub Workflow Usage

### Provision

Run the `Infra Provision` workflow to:
- initialize Terraform with the remote backend
- apply `environments/production.tfvars`
- create ECR and App Runner resources

### Deploy App

Run the `App Deploy` workflow to:
- read ECR and App Runner identifiers from Terraform outputs
- build and push the Docker image to ECR
- update App Runner to the new immutable image tag

### Destroy

Run the `Infra Destroy` workflow to:
- initialize Terraform against the same remote backend
- destroy all managed resources with `ecr_force_delete=true`

## One-Time Bootstrap Outside GitHub Actions

You still need to create these once:
- GitHub OIDC IAM role for Actions
- S3 bucket for Terraform state
- DynamoDB lock table for Terraform state locking

After that, use GitHub Actions as the normal control plane.

## Local Debugging

Local execution is still possible for debugging if you export:
- `AWS_REGION`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `TF_STATE_KEY`

Then run:

```bash
bash scripts/terraform_apply.sh
```

Or:

```bash
bash scripts/terraform_destroy.sh
```

For local image push debugging:

```bash
bash scripts/push_ecr.sh
```
