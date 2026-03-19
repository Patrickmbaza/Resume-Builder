output "aws_account_id" {
  description = "AWS account ID where resources are deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  description = "ECR repository URL to tag and push images."
  value       = aws_ecr_repository.app.repository_url
}

output "apprunner_service_arn" {
  description = "App Runner service ARN."
  value       = var.create_apprunner_service ? aws_apprunner_service.app[0].arn : null
}

output "apprunner_service_url" {
  description = "Public URL of the App Runner service."
  value       = var.create_apprunner_service ? aws_apprunner_service.app[0].service_url : null
}

output "apprunner_status" {
  description = "Current status of App Runner service."
  value       = var.create_apprunner_service ? aws_apprunner_service.app[0].status : "NOT_CREATED"
}
