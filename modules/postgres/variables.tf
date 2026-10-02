variable "name" {
  description = "Identifier prefix for all resources (e.g. 'rag-dev')."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name))
    error_message = "name must be 2-21 chars, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Database-tier subnets (no internet route). At least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS subnet groups need subnets in at least two AZs."
  }
}

variable "engine_version" {
  description = "Postgres major version. Minor versions upgrade automatically."
  type        = string
  default     = "17"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 50
}

variable "database_name" {
  type    = string
  default = "app"
}

variable "master_username" {
  type    = string
  default = "app_admin"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "deletion_protection" {
  description = "Secure default. Dev sets false so it can be destroyed when idle."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  type    = bool
  default = false
}