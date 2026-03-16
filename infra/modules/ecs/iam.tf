data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ===========================================================================
# Task Execution Role — used by the ECS AGENT (not the app)
# Grants permission to: pull the image from ECR, write logs to CloudWatch,
# and retrieve secrets from SSM/Secrets Manager at startup.
# ===========================================================================

resource "aws_iam_role" "task_execution" {
  name               = "${var.project}-${var.environment}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.project}-${var.environment}-task-execution-role"
  }
}

data "aws_iam_policy_document" "task_execution" {
  # ECR: authenticate and pull image layers
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken must be on *
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [var.ecr_repository_arn]
  }

  # CloudWatch Logs: create stream and write log events
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.ecs.arn}:*"]
  }

  # SSM Parameter Store: read app configuration and secrets (extend as needed)
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project}/${var.environment}/*"
    ]
  }

  # Secrets Manager: read database credentials etc. (extend as needed)
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project}/${var.environment}/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_execution" {
  name   = "${var.project}-${var.environment}-task-execution-policy"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution.json
}

# ===========================================================================
# Task Role — used by the APPLICATION CODE inside the container
# Follows least-privilege: only grant what the app explicitly needs.
# Extend this policy as the application gains real AWS resource access.
# ===========================================================================

resource "aws_iam_role" "task" {
  name               = "${var.project}-${var.environment}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.project}-${var.environment}-task-role"
  }
}

# Placeholder policy — add statements as the application grows
data "aws_iam_policy_document" "task" {
  # Example: allow the app to write CloudWatch metrics
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["${var.project}/${var.environment}"]
    }
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${var.project}-${var.environment}-task-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}
