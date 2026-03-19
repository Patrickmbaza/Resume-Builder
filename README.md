# AuraCV Resume Builder

AuraCV is a production-oriented resume builder built with React, TypeScript, and Vite. It provides a guided editor, live resume preview, export support, AI-assisted resume improvement, Docker packaging, and AWS deployment through GitHub Actions, Terraform, ECR, and App Runner.

## What It Does

- Creates resumes through a guided 10-step editor
- Persists resume data in browser local storage
- Renders a live preview while the user edits content
- Supports multiple resume templates and design customization
- Exports resumes as PDF and image
- Uses OpenAI for AI-assisted resume analysis and content improvement
- Builds and deploys through GitHub Actions to AWS App Runner

## Core Features

### Resume Editing

- Personal information, links, and optional profile photo
- Summary and experience level selection
- Experience, education, skills, projects, certifications, and additional sections
- Drag-and-drop reordering for experience and projects
- Design customization for color, typography, and template selection

### Preview and Export

- Real-time preview while editing
- Template switching from the dashboard
- PDF export using `html2pdf.js`
- Image export fallback

### AI Assistance

- AI resume analysis in the final step
- AI-generated resume feedback
- AI-optimized summary suggestions

The app currently uses OpenAI directly from the frontend through:
- [aiService.ts](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/src/services/aiService.ts)

Current model:
- `gpt-4o-mini`

## Tech Stack

- React 19
- TypeScript
- Vite 8
- Tailwind CSS 4
- Zustand
- Framer Motion
- React Router 7
- Docker
- Nginx
- Terraform
- AWS ECR
- AWS App Runner
- GitHub Actions

## Project Structure

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── infra-provision.yml
│       ├── app-deploy.yml
│       └── infra-destroy.yml
├── infra/
│   ├── bootstrap/
│   │   ├── bootstrap_aws.sh
│   │   └── destroy_bootstrap_aws.sh
│   └── terraform/
│       ├── environments/
│       │   └── production.tfvars
│       ├── scripts/
│       │   ├── push_ecr.sh
│       │   ├── terraform_apply.sh
│       │   └── terraform_destroy.sh
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── public/
├── src/
│   ├── components/
│   ├── hooks/
│   ├── pages/
│   ├── services/
│   ├── types/
│   └── main.tsx
├── .env.example
├── .dockerignore
├── Dockerfile
├── nginx.conf
├── package.json
└── README.md
```

## Application Routes

- `/` : landing page
- `/app` : resume builder dashboard

## Editor Flow

The editor currently uses the following 10 steps:

1. Personal Info
2. Summary & Level
3. Experience
4. Education
5. Skills
6. Projects
7. Certifications
8. Additional
9. Design
10. AI Optimize

## Local Development

### Prerequisites

- Node.js 22+
- npm 10+

### Install Dependencies

```bash
npm ci
```

### Start Development Server

```bash
npm run dev
```

### Run Lint

```bash
npm run lint
```

### Create a Production Build

```bash
npm run build
```

### Preview the Production Build

```bash
npm run preview
```

## Environment Variables

This is a Vite application. Only variables prefixed with `VITE_` are available in client-side code.

Example local `.env`:

```dotenv
VITE_OPENAI_API_KEY=your_openai_api_key_here
```

Reference example:
- [.env.example](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.env.example)

### Important Security Note

`VITE_OPENAI_API_KEY` is embedded into the frontend build at build time. That means the deployed client can expose the key to end users. This setup is acceptable only if you understand the risk.

For a truly secure production architecture:
- move AI requests to a backend you control
- store the OpenAI key only on the server
- never expose provider keys to browser clients

## OpenAI Configuration

The project now uses OpenAI directly in:
- [aiService.ts](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/src/services/aiService.ts)

The service expects:
- `VITE_OPENAI_API_KEY`

### Local Usage

Set your key in `.env`:

```dotenv
VITE_OPENAI_API_KEY=sk-...
```

Then run:

```bash
npm run dev
```

### GitHub Actions Usage

Add a GitHub Actions secret:

1. Open your repository on GitHub
2. Go to `Settings`
3. Go to `Secrets and variables`
4. Open `Actions`
5. Open `Secrets`
6. Create:
   - `VITE_OPENAI_API_KEY`

If you prefer environment-scoped secrets:
- create it under the `production` environment instead of repository-wide secrets

The deploy workflow uses that secret during Docker build.

## Docker

The project includes a multi-stage production Docker image:

- build stage: `node:22-alpine`
- runtime stage: `nginx:1.27-alpine`

Files involved:
- [Dockerfile](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/Dockerfile)
- [nginx.conf](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/nginx.conf)
- [.dockerignore](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.dockerignore)

### Build Locally

```bash
export VITE_OPENAI_API_KEY='your_openai_key'
docker build -t resume-builder \
  --secret id=vite_openai_api_key,env=VITE_OPENAI_API_KEY \
  .
```

### Run Locally

```bash
docker run --rm -p 8080:80 resume-builder
```

Open:
- `http://localhost:8080`

## Deployment Model

The intended production control plane is GitHub Actions.

Normal operating flow:

1. `Infra Provision` creates the base infrastructure
2. `App Deploy` builds and pushes the app image, then creates or updates App Runner
3. `Infra Destroy` removes the Terraform-managed app infrastructure

Manual local Terraform and AWS CLI usage should be treated as fallback/debug paths, not the default operating path.

## GitHub Actions Workflows

Workflow files:

- [ci.yml](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.github/workflows/ci.yml)
- [infra-provision.yml](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.github/workflows/infra-provision.yml)
- [app-deploy.yml](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.github/workflows/app-deploy.yml)
- [infra-destroy.yml](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.github/workflows/infra-destroy.yml)

### CI

Runs on push and pull request to `main`.

It performs:
- dependency installation
- lint
- build
- Docker smoke build

### Infra Provision

Runs manually.

It performs:
- Terraform init against the remote backend
- Terraform apply using production settings
- creation of base infrastructure, mainly the ECR repository and related Terraform-managed AWS resources needed before image deployment

### App Deploy

Runs on push to `main` and on manual dispatch.

It performs:
- dependency installation
- lint
- build
- Terraform state lookup for the ECR repository URL
- Docker image build
- image push to ECR using immutable SHA tag
- Terraform apply with:
  - `create_apprunner_service=true`
  - `image_tag=sha-<commit>`

This means App Runner is created or updated from the exact immutable image pushed in the same workflow run.

### Infra Destroy

Runs manually.

It performs:
- Terraform init against the remote backend
- targeted apply to set `ecr_force_delete=true`
- full Terraform destroy

This avoids the common AWS ECR error where non-empty repositories cannot be deleted.

## GitHub Repository Variables

Set these under:
- `Settings -> Secrets and variables -> Actions -> Variables`

Required:

- `AWS_REGION`
- `AWS_ROLE_TO_ASSUME`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `TF_STATE_KEY`

Typical values:

- `AWS_REGION=us-east-1`
- `AWS_ROLE_TO_ASSUME=arn:aws:iam::<account-id>:role/github-actions-resume-builder-deploy`
- `TF_STATE_BUCKET=resume-builder-tf-state-<account-id>`
- `TF_LOCK_TABLE=resume-builder-tf-locks`
- `TF_STATE_KEY=resume-builder/production.tfstate`

## GitHub Repository Secrets

Set these under:
- `Settings -> Secrets and variables -> Actions -> Secrets`

Used by the current project:

- `VITE_OPENAI_API_KEY`

Optional legacy/unused path:

- `VITE_OPENROUTER_API_KEY`

The deploy workflow now avoids passing empty Docker secrets, so missing optional secrets no longer generate noisy warnings.

## AWS Bootstrap

The Terraform remote backend and GitHub OIDC role are bootstrapped outside the main Terraform stack.

Bootstrap script:
- [bootstrap_aws.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/bootstrap/bootstrap_aws.sh)

What it creates:

- S3 bucket for Terraform state
- bucket versioning
- DynamoDB table for Terraform locks
- GitHub OIDC provider
- GitHub Actions IAM role with permissions for:
  - Terraform remote backend access
  - ECR operations
  - IAM role management required by Terraform
  - App Runner operations

### Run Bootstrap

Strict `main`-only trust:

```bash
export GITHUB_ORG_OR_USER="Patrickmbaza"
export GITHUB_REPO="Resume-Builder"
bash infra/bootstrap/bootstrap_aws.sh
```

Wildcard trust for all branches:

```bash
export GITHUB_ORG_OR_USER="Patrickmbaza"
export GITHUB_REPO="Resume-Builder"
export GITHUB_REF_MODE=wildcard
bash infra/bootstrap/bootstrap_aws.sh
```

The script prints the values you should place into GitHub Actions variables.

## Bootstrap Teardown

Bootstrap teardown script:
- [destroy_bootstrap_aws.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/bootstrap/destroy_bootstrap_aws.sh)

What it removes:

- S3 backend bucket, after deleting all versions and delete markers
- DynamoDB lock table
- GitHub Actions IAM role

Optional:
- GitHub OIDC provider

### Run Bootstrap Teardown

Without deleting OIDC provider:

```bash
bash infra/bootstrap/destroy_bootstrap_aws.sh
```

Including OIDC provider:

```bash
DELETE_OIDC_PROVIDER=true bash infra/bootstrap/destroy_bootstrap_aws.sh
```

Use the OIDC deletion path only if you are sure no other repositories or workflows rely on the same provider.

## Terraform

Terraform root:
- `infra/terraform`

Tracked production settings:
- [production.tfvars](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/environments/production.tfvars)

Terraform helper scripts:
- [terraform_apply.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_apply.sh)
- [terraform_destroy.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_destroy.sh)
- [push_ecr.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/push_ecr.sh)

Terraform module documentation:
- [infra/terraform/README.md](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/README.md)

### Current Production Flow

`production.tfvars` intentionally keeps:
- `create_apprunner_service = false`

This is deliberate.

Reason:
- `Infra Provision` should not try to create App Runner before an image exists in ECR
- `App Deploy` overrides this during deployment with:
  - `create_apprunner_service=true`
  - `image_tag=sha-<commit>`

That sequencing avoids `CREATE_FAILED` App Runner services caused by missing images.

## Operational Runbooks

### First-Time Setup

1. Run the bootstrap script.
2. Add GitHub Actions variables.
3. Add `VITE_OPENAI_API_KEY` as a GitHub Actions secret.
4. Run `Infra Provision`.
5. Run `App Deploy`.

### Normal Deploy

1. Push to `main`, or run `App Deploy` manually.
2. Workflow builds the app.
3. Workflow pushes a SHA-tagged image to ECR.
4. Workflow applies Terraform to create or update App Runner.

### Full Teardown

1. Run `Infra Destroy`.
2. If you also want to remove the Terraform backend and GitHub bootstrap resources, run:

```bash
bash infra/bootstrap/destroy_bootstrap_aws.sh
```

## Troubleshooting

### App Runner Fails During Infra Provision

That was the old flow. The current flow avoids this by not creating App Runner during `Infra Provision`.

If you still see it, make sure the latest versions of these files are pushed:
- [production.tfvars](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/environments/production.tfvars)
- [app-deploy.yml](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/.github/workflows/app-deploy.yml)
- [terraform_apply.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_apply.sh)

### ECR Repository Cannot Be Deleted

The destroy helper now handles this by setting `ecr_force_delete=true` before full destroy. If you are debugging locally, use:

```bash
bash infra/terraform/scripts/terraform_destroy.sh
```

### GitHub OIDC Role Cannot Be Assumed

Check:
- the repository name in the IAM trust policy
- whether the trust policy is strict or wildcard
- that `AWS_ROLE_TO_ASSUME` points to the correct role ARN

Use:
- [bootstrap_aws.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/bootstrap/bootstrap_aws.sh)

to regenerate the trust policy cleanly.

### OpenAI Key Is Set But AI Still Fails

Check:
- `VITE_OPENAI_API_KEY` exists in GitHub secrets
- the latest [aiService.ts](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/src/services/aiService.ts) change is pushed
- the deployment was rebuilt after the secret was configured

### Lint Fails in CI

Run locally:

```bash
npm ci
npm run lint
```

The CI pipeline blocks deploys if lint or build fails.

## Security Notes

- This app currently calls OpenAI directly from the frontend.
- Any `VITE_*` secret is available to the built client bundle.
- This is not a secure long-term architecture for paid API usage.

If you want production-grade protection:
- add a backend API
- keep the OpenAI key on the server only
- proxy frontend AI requests through that backend

## Scripts

- AWS bootstrap create:
  - [bootstrap_aws.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/bootstrap/bootstrap_aws.sh)
- AWS bootstrap destroy:
  - [destroy_bootstrap_aws.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/bootstrap/destroy_bootstrap_aws.sh)
- Terraform apply:
  - [terraform_apply.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_apply.sh)
- Terraform destroy:
  - [terraform_destroy.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/terraform_destroy.sh)
- Local ECR push:
  - [push_ecr.sh](/mnt/c/Users/patri/Desktop/DEVOPS-PROJECTS/Resume-builder/infra/terraform/scripts/push_ecr.sh)

## License

No license file is currently included in the repository.
