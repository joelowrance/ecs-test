terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ===========================================================================
# ECR Repository
# ===========================================================================

resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE" # Prevents overwriting existing tags (critical for rollbacks)

  image_scanning_configuration {
    scan_on_push = true # Automatic vulnerability scanning on every push
  }

  tags = {
    Name = var.repository_name
  }
}

# ===========================================================================
# Lifecycle Policy — control image retention to manage storage costs
# ===========================================================================

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        # Rule 1: expire untagged images quickly (dangling layers from failed builds)
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        # Rule 2: keep the most recent N tagged images for rollback capability
        rulePriority = 2
        description  = "Keep last ${var.max_tagged_images} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-", ""]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_tagged_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ===========================================================================
# Repository Policy — restrict pull access to the current account only
# ===========================================================================

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DeleteRepository",
          "ecr:BatchDeleteImage",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy"
        ]
      }
    ]
  })
}
