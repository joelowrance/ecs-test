output "alb_dns_name" {
  description = "DNS name of the ALB — use to access the application"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — use as Docker image base in CI/CD"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used by GitHub Actions deploy workflow"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name — used by GitHub Actions deploy workflow"
  value       = module.ecs.service_name
}

output "log_group_name" {
  description = "CloudWatch log group for ECS task logs"
  value       = module.ecs.log_group_name
}
