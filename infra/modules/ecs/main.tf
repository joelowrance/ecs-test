terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ===========================================================================
# ECS Cluster
# ===========================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled" # CloudWatch Container Insights — metrics, logs, traces
  }

  tags = {
    Name = "${var.project}-${var.environment}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ===========================================================================
# CloudWatch Log Group — structured logs from ECS tasks
# ===========================================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/ecs/${var.project}-${var.environment}"
  }
}

# ===========================================================================
# Security Group — ECS Fargate tasks
# ===========================================================================

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project}-${var.environment}-ecs-sg"
  description = "Allow inbound from ALB on container port; allow all outbound for ECR/CloudWatch"
  vpc_id      = var.vpc_id

  # Ingress from ALB is added via aws_security_group_rule in the environment
  # to avoid a circular dependency with the ALB module.

  egress {
    description = "Allow all outbound (HTTPS for ECR, CloudWatch, Secrets Manager via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-ecs-sg"
  }
}

# ===========================================================================
# ECS Task Definition
# ===========================================================================

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project}-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Required for Fargate; gives each task its own ENI
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ASPNETCORE_ENVIRONMENT"
          value = var.aspnetcore_environment
        }
      ]

      # Health check at container level (separate from ALB health check)
      healthCheck = {
        command     = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        startPeriod = 15
        retries     = 3
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Read-only root filesystem (security hardening)
      readonlyRootFilesystem = false # Set to true and add tmpfs mounts if the app permits

      # Prevent privilege escalation
      privileged             = false
      user                   = "nobody" # Non-root user at runtime
    }
  ])

  tags = {
    Name = "${var.project}-${var.environment}-task"
  }
}

# ===========================================================================
# ECS Service
# ===========================================================================

resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false # Tasks are in private subnets; use NAT for outbound
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true  # Automatically detect failed deployments
    rollback = true  # Automatically roll back to the last stable task definition
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_maximum_percent         = 200 # Allow up to 2x tasks during deployment
  deployment_minimum_healthy_percent = 100 # Never reduce below desired count

  # Ensure the ALB listener exists before creating the service
  depends_on = [var.alb_listener_arn]

  lifecycle {
    # Ignore task_definition changes — CI/CD manages image updates outside Terraform
    ignore_changes = [task_definition]
  }

  tags = {
    Name = "${var.project}-${var.environment}-service"
  }
}
