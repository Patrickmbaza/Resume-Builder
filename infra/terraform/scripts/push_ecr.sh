#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   AWS_REGION=us-east-1 ECR_REPO=resume-builder IMAGE_TAG=latest ./scripts/push_ecr.sh
# Optional:
#   LOCAL_IMAGE=resume-builder ./scripts/push_ecr.sh
#   AWS_ACCOUNT_ID=123456789012 ./scripts/push_ecr.sh

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO="${ECR_REPO:-resume-builder}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
LOCAL_IMAGE="${LOCAL_IMAGE:-resume-builder}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but not installed." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed." >&2
  exit 1
fi

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_IMAGE="${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

echo "Logging in to ECR: ${ECR_REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" | \
docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Tagging image: ${LOCAL_IMAGE}:${IMAGE_TAG} -> ${ECR_IMAGE}"
docker tag "${LOCAL_IMAGE}:${IMAGE_TAG}" "${ECR_IMAGE}"

echo "Pushing image: ${ECR_IMAGE}"
docker push "${ECR_IMAGE}"

echo "Done."
