#!/usr/bin/env bash
set -euo pipefail

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but not installed." >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-resume-builder-tf-state-${AWS_ACCOUNT_ID}}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:-resume-builder-tf-locks}"
ROLE_NAME="${ROLE_NAME:-github-actions-resume-builder-deploy}"
DELETE_OIDC_PROVIDER="${DELETE_OIDC_PROVIDER:-false}"
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

delete_bucket() {
  if ! aws s3api head-bucket --bucket "${TF_STATE_BUCKET}" >/dev/null 2>&1; then
    echo "S3 bucket does not exist: ${TF_STATE_BUCKET}"
    return
  fi

  echo "Emptying S3 bucket versions and delete markers: ${TF_STATE_BUCKET}"
  while true; do
    PAGE="$(aws s3api list-object-versions --bucket "${TF_STATE_BUCKET}" --output json)"
    OBJECTS="$(echo "${PAGE}" | jq '[((.Versions // []) + (.DeleteMarkers // []))[] | {Key: .Key, VersionId: .VersionId}]')"
    COUNT="$(echo "${OBJECTS}" | jq 'length')"
    if [ "${COUNT}" -eq 0 ]; then
      break
    fi
    aws s3api delete-objects \
      --bucket "${TF_STATE_BUCKET}" \
      --delete "{\"Objects\": $(echo "${OBJECTS}" | jq -c '.')}" >/dev/null
  done

  echo "Deleting S3 bucket: ${TF_STATE_BUCKET}"
  aws s3api delete-bucket --bucket "${TF_STATE_BUCKET}" --region "${AWS_REGION}" >/dev/null
}

delete_lock_table() {
  if ! aws dynamodb describe-table --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "DynamoDB table does not exist: ${TF_LOCK_TABLE}"
    return
  fi

  echo "Deleting DynamoDB lock table: ${TF_LOCK_TABLE}"
  aws dynamodb delete-table --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null
}

delete_role() {
  if ! aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
    echo "IAM role does not exist: ${ROLE_NAME}"
    return
  fi

  echo "Deleting inline policies from role: ${ROLE_NAME}"
  while read -r policy_name; do
    [ -n "${policy_name}" ] || continue
    aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "${policy_name}" >/dev/null
  done < <(aws iam list-role-policies --role-name "${ROLE_NAME}" --query 'PolicyNames[]' --output text | tr '\t' '\n')

  echo "Detaching managed policies from role: ${ROLE_NAME}"
  while read -r policy_arn; do
    [ -n "${policy_arn}" ] || continue
    aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${policy_arn}" >/dev/null
  done < <(aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies[].PolicyArn' --output text | tr '\t' '\n')

  echo "Deleting IAM role: ${ROLE_NAME}"
  aws iam delete-role --role-name "${ROLE_NAME}" >/dev/null
}

delete_oidc_provider() {
  if [ "${DELETE_OIDC_PROVIDER}" != "true" ]; then
    echo "Skipping OIDC provider deletion. Set DELETE_OIDC_PROVIDER=true to remove it."
    return
  fi

  if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" >/dev/null 2>&1; then
    echo "OIDC provider does not exist: ${OIDC_PROVIDER_ARN}"
    return
  fi

  echo "Deleting OIDC provider: ${OIDC_PROVIDER_ARN}"
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" >/dev/null
}

delete_bucket
delete_lock_table
delete_role
delete_oidc_provider

echo
echo "Bootstrap teardown complete."
