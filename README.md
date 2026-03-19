# AuraCV Resume Builder

A production-ready React + TypeScript resume builder with:
- Guided 10-step resume editor
- Live preview with template switching
- PDF export
- AI-assisted resume scoring and optimization
- Dockerized deployment
- AWS deployment support via ECR + App Runner + Terraform

## Table of Contents

- Overview
- Features
- Tech Stack
- Project Structure
- Local Development
- Environment Variables
- Build and Run (Local)
- Docker (Production Image)
- AWS Deployment (ECR + App Runner)
- Terraform Infrastructure
- GitHub Actions CI/CD
- Security Notes
- Troubleshooting
- Scripts
- License

## Overview

AuraCV is a frontend-first resume builder designed for fast iteration and production deployment.

The app includes:
- A landing page at `/`
- The editor app at `/app`
- Persistent local storage of resume data in browser localStorage
- AI-driven resume analysis in the final step (requires API key at build time)

## Features

### Resume Builder
- 10-step guided editor:
  - Personal Info
  - Summary & Level
  - Experience
  - Education
  - Skills
  - Projects
  - Certifications
  - Additional
  - Design
  - AI Optimize
- Drag-and-drop reordering for Experience and Projects
- Optional profile photo upload
- Design customization:
  - Theme color
  - Font family
  - Template selection

### Preview and Export
- Real-time preview while editing
- Multiple templates (`classic`, `executive`, `minimal`, `sidebar`, `modern`, `compact`, `elegant`, `bold`, `timeline`, `professional`)
- PDF export using `html2pdf.js`
- PNG export fallback flow

### AI Assistance
- Resume scoring and feedback (Step 10)
- Optimized summary suggestions
- Current implementation uses OpenRouter in `src/services/aiService.ts`

## Tech Stack

- React 19
- TypeScript
- Vite 8
- Tailwind CSS 4
- Zustand (state + persistence)
- Framer Motion
- React Router 7
- Docker + Nginx
- AWS ECR + App Runner
- Terraform

## Project Structure

```text
.
├── src/
│   ├── components/
│   │   ├── editor/
│   │   └── preview/
│   ├── hooks/
│   ├── pages/
│   ├── services/
│   └── types/
├── public/
├── infra/
│   └── terraform/
│       ├── scripts/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── Dockerfile
├── nginx.conf
└── package.json
```

## Local Development

### Prerequisites
- Node.js 22+ (recommended)
- npm 10+

### Install

```bash
npm ci
```

### Run dev server

```bash
npm run dev
```

### Lint

```bash
npm run lint
```

## Environment Variables

This is a Vite frontend app. Only `VITE_*` vars are exposed to client code.

Use `.env`:

```dotenv
VITE_OPENROUTER_API_KEY=your_openrouter_api_key_here
VITE_OPENAI_API_KEY=your_openai_api_key_here
```

Notes:
- `src/services/aiService.ts` currently reads `VITE_OPENROUTER_API_KEY`.
- `VITE_OPENAI_API_KEY` is available for future integration but not used directly in current service code.
- Any key embedded in a frontend build should be treated as non-secret from a backend security perspective.

## Build and Run (Local)

### Production build

```bash
npm run build
```

### Preview build

```bash
npm run preview
```

## Docker (Production Image)

The project includes a multi-stage production Docker image:
- Builder stage: Node 22 Alpine
- Runtime stage: Nginx Alpine

SPA routing is handled by `nginx.conf` using fallback to `/index.html`.

### Build image with BuildKit secrets

`Dockerfile` uses secret mounts for build-time Vite keys.

```bash
export VITE_OPENROUTER_API_KEY='your_openrouter_key'
export VITE_OPENAI_API_KEY='your_openai_key'

docker build -t resume-builder \
  --secret id=vite_openrouter_api_key,env=VITE_OPENROUTER_API_KEY \
  --secret id=vite_openai_api_key,env=VITE_OPENAI_API_KEY \
  .
```

If you only have OpenAI key:

```bash
export VITE_OPENAI_API_KEY='your_openai_key'
docker build -t resume-builder --secret id=vite_openai_api_key,env=VITE_OPENAI_API_KEY .
```

### Run container

```bash
docker run --rm -p 8080:80 resume-builder
```

App URL:
- `http://localhost:8080`

## AWS Deployment (ECR + App Runner)

The intended production model is:
1. GitHub Actions provisions infrastructure with Terraform
2. GitHub Actions builds and pushes the application image to ECR
3. GitHub Actions deploys the image to App Runner

Manual AWS CLI and local Terraform commands are now fallback paths, not the primary operating flow.

## Terraform Infrastructure

Terraform code lives in `infra/terraform/`.

It provisions:
- ECR repository with scan-on-push
- ECR lifecycle policy
- IAM role for App Runner ECR access
- App Runner autoscaling config
- App Runner service

Tracked production configuration lives in:
- `infra/terraform/environments/production.tfvars`

Remote Terraform state is expected for CI/CD ownership:
- S3 bucket for state storage
- DynamoDB table for state locking

The workflows pass backend config at runtime using repository variables, so the same state is used by:
- `Infra Provision`
- `App Deploy`
- `Infra Destroy`

For full Terraform details, see:
- `infra/terraform/README.md`

## GitHub Actions CI/CD

Workflow files:
- `.github/workflows/ci.yml`
- `.github/workflows/infra-provision.yml`
- `.github/workflows/app-deploy.yml`
- `.github/workflows/infra-destroy.yml`

Behavior:
- On pull requests to `main`:
  - Install dependencies
  - Lint
  - Build
  - Docker build smoke test (no push)
- On manual run of `Infra Provision`:
  - Initialize Terraform against remote S3 backend
  - Apply `infra/terraform/environments/production.tfvars`
  - Provision ECR, IAM access role for App Runner, autoscaling, and App Runner service
- On push to `main` or manual run of `App Deploy`:
  - Run full app quality gates
  - Read ECR/App Runner identifiers from Terraform remote state outputs
  - Build and push image to ECR tagged with immutable SHA (`sha-<12-char-commit>`)
  - Update App Runner service to the new image URI
- On manual run of `Infra Destroy`:
  - Initialize Terraform against the same remote backend
  - Destroy the full stack with `ecr_force_delete=true`

Required GitHub repository variables (`Settings -> Secrets and variables -> Actions -> Variables`):
- `AWS_REGION` (example: `us-east-1`)
- `AWS_ROLE_TO_ASSUME` (OIDC assumable IAM role ARN for GitHub Actions)
- `TF_STATE_BUCKET` (S3 bucket used for Terraform remote state)
- `TF_LOCK_TABLE` (DynamoDB table used for Terraform state locking)
- `TF_STATE_KEY` (example: `resume-builder/production.tfstate`)

Optional GitHub repository secrets:
- `VITE_OPENAI_API_KEY`
- `VITE_OPENROUTER_API_KEY`

Notes:
- The workflow uses GitHub OIDC (`aws-actions/configure-aws-credentials`) instead of long-lived AWS keys.
- If you do not use one of the Vite keys, leave that secret unset.
- The IAM role in `AWS_ROLE_TO_ASSUME` must allow at least:
  - Terraform backend access to the S3 state bucket and DynamoDB lock table
  - ECR push permissions (`ecr:GetAuthorizationToken`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`)
  - Terraform-managed infra permissions for ECR, IAM role attachment, App Runner, and autoscaling resources
  - App Runner deploy permissions (`apprunner:DescribeService`, `apprunner:UpdateService`)
- One-time bootstrap still exists outside the pipeline:
  - Create the GitHub OIDC IAM role
  - Create the S3 backend bucket
  - Create the DynamoDB lock table

### First-Time Setup

1. Create the GitHub OIDC role and Terraform backend resources in AWS.
   Use the bootstrap script:

```bash
export GITHUB_ORG_OR_USER="<your-github-user-or-org>"
export GITHUB_REPO="<your-repo-name>"
bash infra/bootstrap/bootstrap_aws.sh
```

For strict trust to `main`, the script defaults to:
- `GITHUB_REF_MODE=exact`
- `GITHUB_REF=refs/heads/main`

If you want the GitHub Actions role to be assumable from any branch in the repo, run:

```bash
export GITHUB_ORG_OR_USER="<your-github-user-or-org>"
export GITHUB_REPO="<your-repo-name>"
export GITHUB_REF_MODE=wildcard
bash infra/bootstrap/bootstrap_aws.sh
```

This script creates:
- the S3 state bucket with versioning enabled
- the DynamoDB lock table
- the GitHub Actions OIDC provider
- the IAM role GitHub Actions assumes

It also prints the GitHub Actions variable values you need to set.

2. Add repository variables:
   - `AWS_REGION`
   - `AWS_ROLE_TO_ASSUME`
   - `TF_STATE_BUCKET`
   - `TF_LOCK_TABLE`
   - `TF_STATE_KEY`
3. Add repository secrets if AI features need them:
   - `VITE_OPENAI_API_KEY`
   - `VITE_OPENROUTER_API_KEY`
4. Run `Infra Provision` from GitHub Actions.
5. Run `App Deploy` from GitHub Actions, or push to `main`.

### Source of Truth

Production AWS resources should be created, updated, and destroyed through the GitHub Actions workflows above. Local Terraform commands are useful for debugging, but they should not be the routine path once the remote backend and workflows are in place.

## Security Notes

- `VITE_*` values are embedded into frontend assets at build time.
- Do not treat frontend API keys as server-side secrets.
- For strict production security, move AI calls to a backend API and keep provider keys server-side.

## Troubleshooting

### Docker multiline command fails with `--secret: command not found`
Cause: broken line continuation in shell.

Use single line:

```bash
docker build -t resume-builder --secret id=vite_openai_api_key,env=VITE_OPENAI_API_KEY .
```

### ECR lifecycle policy apply error
If you previously saw lifecycle validation issues, ensure latest Terraform in repo is applied.

### Infra destroy fails for ECR not empty
Use the `Infra Destroy` workflow first. It already passes `ecr_force_delete=true`.

If you are debugging locally and it still fails, manually delete ECR images and retry:

```bash
aws ecr list-images --repository-name resume-builder --region us-east-1 --query 'imageIds[*]' --output json > /tmp/image_ids.json
aws ecr batch-delete-image --repository-name resume-builder --region us-east-1 --image-ids "$(cat /tmp/image_ids.json)"
terraform destroy -var="ecr_force_delete=true"
```

### Warning: commit information not captured during Docker build
This warning is non-blocking and does not affect runtime behavior.

## Scripts

- Terraform apply helper used by GitHub Actions:
  - [terraform_apply.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_apply.sh)
- Terraform destroy helper used by GitHub Actions:
  - [terraform_destroy.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_destroy.sh)
- AWS bootstrap helper for the one-time backend and OIDC setup:
  - [bootstrap_aws.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/bootstrap/bootstrap_aws.sh)
- Local ECR image push helper:
  - [infra/terraform/scripts/push_ecr.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/push_ecr.sh)

## License

No license file is currently included. Add a `LICENSE` file if you plan to distribute this project.
