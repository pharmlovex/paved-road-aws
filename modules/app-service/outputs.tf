output "service_security_group_id" {
  value = aws_security_group.service.id
}
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_role_arn" {
  description = "Exposed so environments can attach app-specific permissions (e.g. Bedrock for the RAG app) without editing the module."
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}