variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project     = "resume-builder"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

variable "ecr_repository_name" {
  description = "ECR repository name."
  type        = string
  default     = "resume-builder"
}

variable "ecr_image_tag_mutability" {
  description = "ECR tag mutability. IMMUTABLE is recommended for production."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "ecr_max_image_count" {
  description = "Max number of images to keep in ECR lifecycle policy."
  type        = number
  default     = 30
}

variable "ecr_force_delete" {
  description = "Allow deleting a non-empty ECR repository during terraform destroy."
  type        = bool
  default     = false
}

variable "create_apprunner_service" {
  description = "Create App Runner service. Set false for first apply, then true after first image push."
  type        = bool
  default     = false
}

variable "apprunner_service_name" {
  description = "App Runner service name."
  type        = string
  default     = "resume-builder"
}

variable "image_tag" {
  description = "Container image tag in ECR for App Runner deployment."
  type        = string
  default     = "latest"
}

variable "apprunner_cpu" {
  description = "App Runner instance CPU."
  type        = string
  default     = "1024"
}

variable "apprunner_memory" {
  description = "App Runner instance memory."
  type        = string
  default     = "2048"
}

variable "apprunner_port" {
  description = "Container port App Runner should route traffic to."
  type        = string
  default     = "80"
}

variable "apprunner_auto_deployments_enabled" {
  description = "Enable automatic deployment when image tag updates in ECR."
  type        = bool
  default     = true
}

variable "apprunner_min_size" {
  description = "Minimum number of active instances for App Runner autoscaling."
  type        = number
  default     = 1
}

variable "apprunner_max_size" {
  description = "Maximum number of active instances for App Runner autoscaling."
  type        = number
  default     = 5
}

variable "apprunner_max_concurrency" {
  description = "Max concurrent requests per instance before scaling."
  type        = number
  default     = 100
}

variable "apprunner_health_check_path" {
  description = "HTTP health check path for App Runner."
  type        = string
  default     = "/"
}

variable "apprunner_health_check_interval" {
  description = "Health check interval in seconds."
  type        = number
  default     = 10
}

variable "apprunner_health_check_timeout" {
  description = "Health check timeout in seconds."
  type        = number
  default     = 5
}

variable "apprunner_healthy_threshold" {
  description = "Consecutive successful checks required to mark healthy."
  type        = number
  default     = 1
}

variable "apprunner_unhealthy_threshold" {
  description = "Consecutive failed checks required to mark unhealthy."
  type        = number
  default     = 5
}

variable "apprunner_observability_enabled" {
  description = "Enable App Runner observability configuration."
  type        = bool
  default     = false
}

variable "apprunner_kms_key_arn" {
  description = "Optional KMS key ARN for App Runner encryption configuration. Null uses AWS-managed encryption."
  type        = string
  default     = null
}

variable "runtime_environment_variables" {
  description = "Runtime environment variables for container. Avoid placing secrets here for frontend apps."
  type        = map(string)
  default     = {}
}
