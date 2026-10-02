variable "name" {
  type        = string
  description = "Name prefix for all network resources, e.g. paved-road-dev"
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR, e.g. 10.10.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "At least 2 AZs are required (the ALB needs two)."
  }
}

variable "nat_mode" {
  type    = string
  default = "none"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_mode)
    error_message = "nat_mode must be one of: none, single, per_az."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}