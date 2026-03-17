terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ===========================================================================
# Security Group — ALB (internet-facing)
# ===========================================================================

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Allow HTTP inbound to ALB; restrict egress to ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to ECS tasks is added via aws_security_group_rule in the environment
  # to avoid a circular dependency with the ECS module.

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

# ===========================================================================
# Application Load Balancer
# ===========================================================================

resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Enable access logs in production (requires an S3 bucket — extend as needed)
  # access_logs { bucket = ... }

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# ===========================================================================
# Target Group — ECS tasks register here as IP targets (awsvpc mode)
# ===========================================================================

resource "aws_lb_target_group" "main" {
  name        = "${var.project}-${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate awsvpc network mode

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Allow in-flight requests to complete during deregistration (draining)
  deregistration_delay = 30

  tags = {
    Name = "${var.project}-${var.environment}-tg"
  }
}

# ===========================================================================
# Listener — HTTP:80 → forward to target group
# ===========================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name = "${var.project}-${var.environment}-listener-http"
  }
}
