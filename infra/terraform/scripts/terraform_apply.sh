#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT="${TF_ENVIRONMENT:-production}"
TF_VARS_FILE="${TF_VARS_FILE:-${ROOT_DIR}/environments/${ENVIRONMENT}.tfvars}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required but not installed." >&2
  exit 1
fi

if [ ! -f "${TF_VARS_FILE}" ]; then
  echo "Terraform vars file not found: ${TF_VARS_FILE}" >&2
  exit 1
fi

terraform -chdir="${ROOT_DIR}" init \
  -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${TF_STATE_KEY}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}"

terraform -chdir="${ROOT_DIR}" apply \
  -input=false \
  -auto-approve \
  -var-file="${TF_VARS_FILE}" \
  "$@"
