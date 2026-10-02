variable "name" {
  description = "Service name; used as a prefix. Short, because ALB and target group names max out at 32 chars."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name))
    error_message = "name must be 2-21 chars, lowercase letters, digits and hyphens, starting with a letter."
  }
}

# --- Network ---------------------------------------------------------------

variable "vpc_id" {
  type = string
}

variable "alb_subnet_ids" {
  description = "Public subnets for the load balancer."
  type        = list(string)
}

variable "service_subnet_ids" {
  description = "Subnets for Fargate tasks (public in dev per ADR 0002, private in prod)."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Required when tasks run in public subnets without NAT (ADR 0002). Inbound is still ALB-only."
  type        = bool
  default     = false
}

variable "alb_ingress_cidrs" {
  description = "Who may reach the ALB on 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- DNS / TLS -------------------------------------------------------------

variable "certificate_arn" {
  description = "Validated ACM cert from global/dns."
  type        = string
}

variable "route53_zone_id" {
  type = string
}

variable "hostname" {
  description = "FQDN for this service, e.g. dev.paved-road.kowopeweb.com."
  type        = string
}

# --- Container -------------------------------------------------------------

variable "container_image" {
  description = "Full image reference. Prefer an immutable digest or tag over 'latest'."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be one of 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Fargate task memory in MiB (must be a valid pairing with cpu)."
  type        = number
  default     = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "environment_variables" {
  description = "Plain, non-secret environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = <<-EOT
    Env var name => Secrets Manager reference. json_key selects one field of a JSON secret.
    The module grants the execution role read access to exactly these secrets.
  EOT
  type = map(object({
    secret_arn = string
    json_key   = optional(string)
  }))
  default = {}
}

# --- Database access -------------------------------------------------------

variable "database_access" {
  description = "If set, the service is allowed to reach this database security group on this port."
  type = object({
    security_group_id = string
    port              = number
  })
  default = null
}

# --- Observability ---------------------------------------------------------

variable "log_retention_days" {
  type    = number
  default = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch-supported value."
  }
}

variable "alarm_sns_topic_arn" {
  description = "Where alarms notify. null = alarms still exist and show in the console, but notify nobody."
  type        = string
  default     = null
}