aws_region               = "us-east-1"
ecr_repository_name      = "resume-builder"
create_apprunner_service = false
apprunner_service_name   = "resume-builder"
image_tag                = "latest"

tags = {
  Project     = "resume-builder"
  Environment = "production"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
}
