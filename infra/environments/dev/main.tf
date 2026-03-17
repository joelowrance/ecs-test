terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ===========================================================================
# Networking
# ===========================================================================

module "vpc" {
  source = "../../modules/vpc"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
}

# ===========================================================================
# Container Registry
# ===========================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_name   = "${var.project}-${var.environment}"
  max_tagged_images = 10
}

# ===========================================================================
# Load Balancer
# The ALB module needs the ECS security group ID to scope its egress rule.
# We break the circular dependency by creating the ECS SG in the ECS module
# and passing it to the ALB module.
# ===========================================================================

module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # These reference the ALB module — Terraform resolves the dependency graph.
  target_group_arn = module.alb.target_group_arn
  alb_listener_arn = module.alb.listener_arn

  ecr_repository_arn = module.ecr.repository_arn

  service_name    = "api"
  container_image = "${module.ecr.repository_url}:latest"
  container_port  = 8080

  task_cpu    = var.task_cpu
  task_memory = var.task_memory

  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  aspnetcore_environment = "Production"
  log_retention_days     = 14 # Shorter retention in dev
}

module "alb" {
  source = "../../modules/alb"

  project     = var.project
  environment = var.environment

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  container_port = 8080
}

# ===========================================================================
# Security Group Rules — cross-module rules added here to break the cycle
# between the ALB and ECS modules.
# ===========================================================================

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  description              = "Forward to ECS tasks on container port"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = module.alb.alb_security_group_id
  source_security_group_id = module.ecs.ecs_security_group_id
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  description              = "Container port from ALB only"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = module.ecs.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
}
