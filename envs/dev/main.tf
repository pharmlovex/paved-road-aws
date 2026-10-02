module "vpc" {
  source = "../../modules/vpc"

  name       = "paved-road-dev"
  cidr_block = "10.10.0.0/16"
  nat_mode   = "none" # ADR 0002: no NAT in dev
}