data "aws_caller_identity" "current" {}

locals {
  image_identifier = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
}

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.ecr_image_tag_mutability
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_iam_role" "apprunner_ecr_access" {
  count = var.create_apprunner_service ? 1 : 0

  name = "${var.apprunner_service_name}-apprunner-ecr-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  count = var.create_apprunner_service ? 1 : 0

  role       = aws_iam_role.apprunner_ecr_access[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_apprunner_auto_scaling_configuration_version" "app" {
  count = var.create_apprunner_service ? 1 : 0

  auto_scaling_configuration_name = "${var.apprunner_service_name}-autoscaling"
  max_concurrency                 = var.apprunner_max_concurrency
  max_size                        = var.apprunner_max_size
  min_size                        = var.apprunner_min_size
}

resource "aws_apprunner_observability_configuration" "app" {
  count = var.create_apprunner_service && var.apprunner_observability_enabled ? 1 : 0

  observability_configuration_name = "${var.apprunner_service_name}-observability"
  trace_configuration {
    vendor = "AWSXRAY"
  }
}

resource "aws_apprunner_service" "app" {
  count = var.create_apprunner_service ? 1 : 0

  service_name = var.apprunner_service_name

  source_configuration {
    auto_deployments_enabled = var.apprunner_auto_deployments_enabled

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access[0].arn
    }

    image_repository {
      image_identifier      = local.image_identifier
      image_repository_type = "ECR"

      image_configuration {
        port                          = var.apprunner_port
        runtime_environment_variables = var.runtime_environment_variables
      }
    }
  }

  instance_configuration {
    cpu    = var.apprunner_cpu
    memory = var.apprunner_memory
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = var.apprunner_health_check_path
    interval            = var.apprunner_health_check_interval
    timeout             = var.apprunner_health_check_timeout
    healthy_threshold   = var.apprunner_healthy_threshold
    unhealthy_threshold = var.apprunner_unhealthy_threshold
  }

  network_configuration {
    egress_configuration {
      egress_type = "DEFAULT"
    }

    ingress_configuration {
      is_publicly_accessible = true
    }
  }

  dynamic "encryption_configuration" {
    for_each = var.apprunner_kms_key_arn == null ? [] : [1]
    content {
      kms_key = var.apprunner_kms_key_arn
    }
  }

  dynamic "observability_configuration" {
    for_each = var.apprunner_observability_enabled ? [1] : []
    content {
      observability_enabled           = true
      observability_configuration_arn = aws_apprunner_observability_configuration.app[0].observability_configuration_arn
    }
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.app[0].arn

  depends_on = [
    aws_iam_role_policy_attachment.apprunner_ecr_access
  ]
}
