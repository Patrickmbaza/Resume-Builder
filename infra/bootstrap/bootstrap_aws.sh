#!/usr/bin/env bash
set -euo pipefail

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but not installed." >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
GITHUB_ORG_OR_USER="${GITHUB_ORG_OR_USER:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-resume-builder-tf-state-${AWS_ACCOUNT_ID}}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:-resume-builder-tf-locks}"
TF_STATE_KEY="${TF_STATE_KEY:-resume-builder/production.tfstate}"
ROLE_NAME="${ROLE_NAME:-github-actions-resume-builder-deploy}"
GITHUB_REF_MODE="${GITHUB_REF_MODE:-exact}"
GITHUB_REF="${GITHUB_REF:-refs/heads/main}"

if [ -z "${GITHUB_ORG_OR_USER}" ] || [ -z "${GITHUB_REPO}" ]; then
  echo "Set GITHUB_ORG_OR_USER and GITHUB_REPO before running this script." >&2
  exit 1
fi

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if [ "${GITHUB_REF_MODE}" = "wildcard" ]; then
  GITHUB_SUB_PATTERN="${GITHUB_SUB_PATTERN:-repo:${GITHUB_ORG_OR_USER}/${GITHUB_REPO}:*}"
else
  GITHUB_SUB="${GITHUB_SUB:-repo:${GITHUB_ORG_OR_USER}/${GITHUB_REPO}:ref:${GITHUB_REF}}"
fi

create_bucket() {
  if aws s3api head-bucket --bucket "${TF_STATE_BUCKET}" >/dev/null 2>&1; then
    echo "S3 bucket already exists: ${TF_STATE_BUCKET}"
    return
  fi

  echo "Creating S3 bucket: ${TF_STATE_BUCKET}"
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${TF_STATE_BUCKET}" \
      --region "${AWS_REGION}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${TF_STATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
  fi

  echo "Enabling versioning on bucket: ${TF_STATE_BUCKET}"
  aws s3api put-bucket-versioning \
    --bucket "${TF_STATE_BUCKET}" \
    --versioning-configuration Status=Enabled >/dev/null
}

create_lock_table() {
  if aws dynamodb describe-table --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "DynamoDB table already exists: ${TF_LOCK_TABLE}"
    return
  fi

  echo "Creating DynamoDB lock table: ${TF_LOCK_TABLE}"
  aws dynamodb create-table \
    --table-name "${TF_LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}" >/dev/null
}

create_oidc_provider() {
  if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" >/dev/null 2>&1; then
    echo "OIDC provider already exists: ${OIDC_PROVIDER_ARN}"
    return
  fi

  echo "Creating GitHub Actions OIDC provider"
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
}

write_trust_policy() {
  if [ "${GITHUB_REF_MODE}" = "wildcard" ]; then
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "${GITHUB_SUB_PATTERN}"
        }
      }
    }
  ]
}
EOF
  else
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "${GITHUB_SUB}"
        }
      }
    }
  ]
}
EOF
  fi
}

write_role_policy() {
  cat > gha-deploy-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${TF_STATE_BUCKET}",
        "arn:aws:s3:::${TF_STATE_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${TF_LOCK_TABLE}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:PutLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:ListImages",
        "ecr:BatchDeleteImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PassRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apprunner:CreateService",
        "apprunner:UpdateService",
        "apprunner:DeleteService",
        "apprunner:DescribeService",
        "apprunner:CreateAutoScalingConfiguration",
        "apprunner:DeleteAutoScalingConfiguration",
        "apprunner:CreateObservabilityConfiguration",
        "apprunner:DeleteObservabilityConfiguration"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

create_or_update_role() {
  write_trust_policy
  write_role_policy

  if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
    echo "Updating IAM role trust policy: ${ROLE_NAME}"
    aws iam update-assume-role-policy \
      --role-name "${ROLE_NAME}" \
      --policy-document file://trust-policy.json >/dev/null
  else
    echo "Creating IAM role: ${ROLE_NAME}"
    aws iam create-role \
      --role-name "${ROLE_NAME}" \
      --assume-role-policy-document file://trust-policy.json >/dev/null
  fi

  echo "Applying inline policy to role: ${ROLE_NAME}"
  aws iam put-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-name GitHubActionsResumeBuilderDeploy \
    --policy-document file://gha-deploy-policy.json >/dev/null
}

print_outputs() {
  ROLE_ARN="$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)"

  echo
  echo "Bootstrap complete. Set these GitHub Actions variables:"
  echo "AWS_REGION=${AWS_REGION}"
  echo "AWS_ROLE_TO_ASSUME=${ROLE_ARN}"
  echo "TF_STATE_BUCKET=${TF_STATE_BUCKET}"
  echo "TF_LOCK_TABLE=${TF_LOCK_TABLE}"
  echo "TF_STATE_KEY=${TF_STATE_KEY}"
  if [ "${GITHUB_REF_MODE}" = "wildcard" ]; then
    echo "OIDC_SUB_PATTERN=${GITHUB_SUB_PATTERN}"
  else
    echo "OIDC_SUB=${GITHUB_SUB}"
  fi
}

create_bucket
create_lock_table
create_oidc_provider
create_or_update_role
print_outputs
