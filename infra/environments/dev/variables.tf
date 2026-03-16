variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost saving for non-prod)"
  type        = bool
}

variable "task_cpu" {
  description = "ECS task CPU units"
  type        = number
}

variable "task_memory" {
  description = "ECS task memory MiB"
  type        = number
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "min_capacity" {
  description = "Minimum tasks for autoscaling"
  type        = number
}

variable "max_capacity" {
  description = "Maximum tasks for autoscaling"
  type        = number
}
