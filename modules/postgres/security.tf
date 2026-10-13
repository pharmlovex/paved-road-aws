# No rules here on purpose: consumers add their own ingress (ADR 0003),
# and RDS never needs outbound connections.
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-db-"
  description = "Postgres for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db" }

  lifecycle {
    create_before_destroy = true
  }
}