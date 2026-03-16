terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

locals {
  # Derive AZ-specific subnet CIDRs by splitting the VPC CIDR into /24 blocks.
  # Public subnets get the first two blocks; private subnets get the next two.
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_cidrs    = [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1)]
  private_cidrs   = [cidrsubnet(var.vpc_cidr, 8, 10), cidrsubnet(var.vpc_cidr, 8, 11)]
  nat_gateway_count = var.single_nat_gateway ? 1 : length(local.azs)
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ===========================================================================
# VPC
# ===========================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

# ===========================================================================
# Public subnets (ALB lives here — internet-facing)
# ===========================================================================

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # ALB manages its own public IPs

  tags = {
    Name = "${var.project}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  }
}

# ===========================================================================
# Private subnets (ECS Fargate tasks live here — no public IPs)
# ===========================================================================

resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
    Tier = "private"
  }
}

# ===========================================================================
# Internet Gateway — public internet access for ALB
# ===========================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# ===========================================================================
# NAT Gateway — outbound internet for ECS tasks (ECR pull, external APIs)
# In dev: single NAT GW (cost optimisation)
# In prod: one per AZ (high availability)
# ===========================================================================

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = {
    Name = "${var.project}-${var.environment}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project}-${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ===========================================================================
# Route Tables
# ===========================================================================

# Public route table → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables → NAT GW (one per AZ in prod, shared in dev)
resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = {
    Name = "${var.project}-${var.environment}-rt-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
