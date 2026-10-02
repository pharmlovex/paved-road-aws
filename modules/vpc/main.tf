data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # { "eu-west-2a" = 0, "eu-west-2b" = 1 }
  az_index = { for i, az in local.azs : az => i }

  # How many NAT gateways: none = 0, single = 1, per_az = one per AZ
  nat_count = (
    var.nat_mode == "per_az" ? length(local.azs) :
    var.nat_mode == "single" ? 1 : 0
  )

  # Which AZs host a NAT gateway: [], ["eu-west-2a"], or both
  nat_azs = slice(local.azs, 0, local.nat_count)

  # For each AZ, which NAT gateway its private subnet should use
  nat_az_for = {
    for az in local.azs : az => (var.nat_mode == "per_az" ? az : local.azs[0])
  }
}

# ---------- VPC and internet gateway ----------

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true # needed by RDS endpoints and VPC endpoints

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# Lock down the default security group so nothing can accidentally use it.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-default-deny" })
}

# ---------- Subnets ----------

resource "aws_subnet" "public" {
  for_each = local.az_index

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, 8, each.value)

  # Workloads must opt in to a public IP explicitly.
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name}-public-${each.key}", Tier = "public" })
}

resource "aws_subnet" "private" {
  for_each = local.az_index

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, 8, 10 + each.value)

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}", Tier = "private" })
}

resource "aws_subnet" "database" {
  for_each = local.az_index

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, 8, 20 + each.value)

  tags = merge(var.tags, { Name = "${var.name}-database-${each.key}", Tier = "database" })
}

# ---------- Routing: public ----------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------- Routing: private (one table per AZ, NAT routes added next step) ----------

resource "aws_route_table" "private" {
  for_each = local.az_index
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------- Routing: database (no internet route, ever) ----------

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-database" })
}

resource "aws_route_table_association" "database" {
  for_each       = aws_subnet.database
  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}

# ---------- NAT (controlled by nat_mode) ----------

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id # NAT lives in a PUBLIC subnet
  tags          = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  # The NAT gateway needs the internet gateway to exist first.
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  for_each = var.nat_mode == "none" ? {} : local.az_index

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.nat_az_for[each.key]].id
}

# ---------- S3 gateway endpoint (free) ----------

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  # Public and private tiers can reach S3 privately. The database tier doesn't need it.
  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.private : rt.id],
  )

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}