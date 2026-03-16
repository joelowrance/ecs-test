variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for ECS task placement"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (ECS tasks allow ingress from this SG)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener (used as depends_on to ensure ordering)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository (scoped in the task execution IAM policy)"
  type        = string
}

variable "service_name" {
  description = "ECS service name (also used as the container name in the task definition)"
  type        = string
  default     = "api"
}

variable "container_image" {
  description = "Full Docker image URI including tag (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:v1.0.0)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS task instances"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 4
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilisation percentage for auto scaling (0–100)"
  type        = number
  default     = 70
}

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 30
}

variable "aspnetcore_environment" {
  description = "Value for ASPNETCORE_ENVIRONMENT environment variable"
  type        = string
  default     = "Production"
}
