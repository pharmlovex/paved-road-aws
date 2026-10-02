# Placeholders until step 3.5; values are wired to real resources then.
output "address" {
  value = null
}

output "port" {
  value = 5432
}

output "database_name" {
  value = var.database_name
}

output "security_group_id" {
  value = null
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the RDS-managed master credentials (JSON: username, password)."
  value       = null
}

output "instance_identifier" {
  description = "For CloudWatch alarm dimensions."
  value       = null
}