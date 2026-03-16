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
  single_nat_gateway = var.single_nat_gateway # false in prod = 1 NAT GW per AZ
}

# ===========================================================================
# Container Registry
# ===========================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_name   = "${var.project}-${var.environment}"
  max_tagged_images = 20 # Keep more images in prod for audit/rollback history
}

# ===========================================================================
# ECS + ALB
# ===========================================================================

module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  alb_listener_arn      = module.alb.listener_arn

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
  log_retention_days     = 90 # Longer retention in prod for compliance/auditing
}

module "alb" {
  source = "../../modules/alb"

  project     = var.project
  environment = var.environment

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  ecs_security_group_id = module.ecs.ecs_security_group_id

  container_port = 8080
}
