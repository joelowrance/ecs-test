# ===========================================================================
# GitHub Actions OIDC — allows GitHub Actions to authenticate with AWS
# without long-lived credentials.
#
# The OIDC provider is account-level (one per account). If you already have
# one for token.actions.githubusercontent.com, import it instead of creating:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<account_id>:oidc-provider/token.actions.githubusercontent.com
# ===========================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ===========================================================================
# IAM Role — assumed by GitHub Actions during deploy-dev workflow
# ===========================================================================

resource "aws_iam_role" "github_actions_dev" {
  name = "github-actions-ecs-deploy-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Scope to this repo only (sub changes to environment:dev when a GitHub environment is used)
            "token.actions.githubusercontent.com:sub" = "repo:joelowrance/ecs-test:*"
          }
        }
      }
    ]
  })
}

# ===========================================================================
# IAM Policy — minimum permissions for the deploy workflow:
#   - ECR: authenticate + push image
#   - ECS: read task definition, register new revision, update service
#   - IAM: pass the task execution and task roles to ECS
# ===========================================================================

resource "aws_iam_role_policy" "github_actions_dev" {
  name = "github-actions-ecs-deploy-dev-policy"
  role = aws_iam_role.github_actions_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = module.ecr.repository_arn
      },
      {
        Sid    = "ECSDeployDev"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRolesToECS"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          module.ecs.task_execution_role_arn,
          module.ecs.task_role_arn
        ]
      }
    ]
  })
}
