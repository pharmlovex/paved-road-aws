# --- ALB: the only thing reachable from the internet ----------------------

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "ALB for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  # Every allowed CIDR on both 80 (redirect) and 443 (HTTPS).
  alb_ingress = {
    for pair in setproduct(var.alb_ingress_cidrs, [80, 443]) :
    "${pair[0]}-${pair[1]}" => { cidr = pair[0], port = pair[1] }
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_clients" {
  for_each = local.alb_ingress

  security_group_id = aws_security_group.alb.id
  description       = "Clients to ALB on ${each.value.port}"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to tasks (traffic and health checks)"
  referenced_security_group_id = aws_security_group.service.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# --- Service: reachable only from the ALB ---------------------------------

resource "aws_security_group" "service" {
  name_prefix = "${var.name}-svc-"
  description = "Fargate tasks for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-svc" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id            = aws_security_group.service.id
  description                  = "Only the ALB may reach tasks (ADR 0002)"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "service_https" {
  security_group_id = aws_security_group.service.id
  description       = "HTTPS out: ECR, Secrets Manager, CloudWatch Logs, external APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# --- Database access: the consumer opens the door to itself (ADR 0003) ----

resource "aws_vpc_security_group_egress_rule" "service_to_database" {
  count = var.database_access == null ? 0 : 1

  security_group_id            = aws_security_group.service.id
  description                  = "Tasks to database"
  referenced_security_group_id = var.database_access.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.database_access.port
  to_port                      = var.database_access.port
}

resource "aws_vpc_security_group_ingress_rule" "database_from_service" {
  count = var.database_access == null ? 0 : 1

  security_group_id            = var.database_access.security_group_id
  description                  = "${var.name} tasks to database"
  referenced_security_group_id = aws_security_group.service.id
  ip_protocol                  = "tcp"
  from_port                    = var.database_access.port
  to_port                      = var.database_access.port
}