module "vpc" {
  source = "../../modules/vpc"

  name       = "paved-road-dev"
  cidr_block = "10.10.0.0/16"
  nat_mode   = "none" # ADR 0002: no NAT in dev
}

# Look up the long-lived DNS resources by name rather than reading
# global/dns's state file. This couples dev to what exists in AWS,
# not to another stack's internal state or its encryption keys.
data "aws_route53_zone" "paved_road" {
  name         = "paved-road.kowopeweb.com"
  private_zone = false
}

data "aws_acm_certificate" "wildcard" {
  domain      = "*.paved-road.kowopeweb.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

module "postgres" {
  source = "../../modules/postgres"

  name       = "rag-dev"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  # Dev is disposable (destroy when idle). Prod keeps the secure defaults.
  deletion_protection   = false
  skip_final_snapshot   = true
  backup_retention_days = 1
}

module "app_service" {
  source = "../../modules/app-service"

  name   = "rag-dev"
  vpc_id = module.vpc.vpc_id

  alb_subnet_ids     = module.vpc.public_subnet_ids
  service_subnet_ids = module.vpc.public_subnet_ids # ADR 0002: no NAT in dev
  assign_public_ip   = true

  certificate_arn = data.aws_acm_certificate.wildcard.arn
  route53_zone_id = data.aws_route53_zone.paved_road.zone_id
  hostname        = "dev.paved-road.kowopeweb.com"

  # Placeholder; we choose the real test image in step 3.8.
  container_image = "nginxinc/nginx-unprivileged:1.27-alpine"
  container_port  = 8080

  database_access = {
    security_group_id = module.postgres.security_group_id
    port              = module.postgres.port
  }
}