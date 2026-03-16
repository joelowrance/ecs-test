output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "ARN of the most recent task definition revision"
  value       = aws_ecs_task_definition.main.arn
}

output "task_execution_role_arn" {
  description = "ARN of the task execution IAM role"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the task IAM role"
  value       = aws_iam_role.task.arn
}

output "ecs_security_group_id" {
  description = "Security group ID attached to ECS tasks (reference in ALB module)"
  value       = aws_security_group.ecs_tasks.id
}

output "log_group_name" {
  description = "CloudWatch log group name for ECS tasks"
  value       = aws_cloudwatch_log_group.ecs.name
}
