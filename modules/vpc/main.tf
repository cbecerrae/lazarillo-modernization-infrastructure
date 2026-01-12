# Local values to control NAT AZ selection only
locals {
  nat_az_ids = var.single_az ? [var.aws_availability_zones_ids[0]] : var.aws_availability_zones_ids
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Public subnets (/24) in all AZs
resource "aws_subnet" "public" {
  for_each = { for idx, az_id in var.aws_availability_zones_ids : idx => az_id }

  vpc_id               = aws_vpc.main.id
  cidr_block           = cidrsubnet(var.vpc_cidr, 8, each.key)
  availability_zone_id = each.value

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet-${each.value}"
  }
}

# Private subnets (/24) in all AZs
resource "aws_subnet" "private" {
  for_each = { for idx, az_id in var.aws_availability_zones_ids : idx => az_id }

  vpc_id               = aws_vpc.main.id
  cidr_block           = cidrsubnet(var.vpc_cidr, 8, each.key + 10)
  availability_zone_id = each.value

  tags = {
    Name = "${var.project_name}-${var.environment}-private-subnet-${each.value}"
  }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rtb-public"
  }
}

# Route to Internet Gateway
resource "aws_route" "public_to_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Elastic IPs for Regional NAT Gateway (controlled by single_az)
resource "aws_eip" "nat" {
  for_each = { for idx, az_id in local.nat_az_ids : idx => az_id }

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${each.value}"
  }
}

# Regional NAT Gateway
resource "aws_nat_gateway" "regional" {
  vpc_id            = aws_vpc.main.id
  availability_mode = "regional"

  # Define EIPs per AZ for the Regional NAT Gateway
  dynamic "availability_zone_address" {
    for_each = { for idx, az_id in local.nat_az_ids : idx => az_id }

    content {
      availability_zone_id = availability_zone_address.value
      allocation_ids       = [aws_eip.nat[availability_zone_address.key].id]
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-regional"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private route table (shared for all AZs)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rtb-private"
  }
}

# Route from private subnets to Regional NAT Gateway
resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.regional.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Tag the default route table
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = {
    Name = "${var.project_name}-${var.environment}-rtb-default"
  }
}

# Tag the default security group
resource "aws_ec2_tag" "default_sg_tag" {
  resource_id = aws_vpc.main.default_security_group_id
  key         = "Name"
  value       = "default"
}
