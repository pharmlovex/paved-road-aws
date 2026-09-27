data "aws_caller_identity" "current" {}

locals {
  # Bucket names are global across ALL of AWS. Adding your account ID makes it unique.
  state_bucket_name = "paved-road-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  # Losing this bucket means losing track of your whole platform. Make deleting it deliberate.
  lifecycle {
    prevent_destroy = true
  }
}

# Every change to state keeps the old version, so you can roll back a corrupted state file.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State must never be public. Belt and braces.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Alerts you when AWS forecasts you'll pass 80% of your budget, before the money is spent.
resource "aws_budgets_budget" "monthly" {
  name         = "paved-road-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}