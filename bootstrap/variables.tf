variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "budget_email" {
  type        = string
  description = "Where budget alerts are sent"
}

variable "monthly_budget_usd" {
  type    = string
  default = "30"
}