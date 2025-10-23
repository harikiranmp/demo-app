#############################################
# VPC Module - main.tf (NAT Instance Ready)
#############################################

# -----------------------------
# Create VPC
# -----------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name}-vpc" })
}

# -----------------------------
# Internet Gateway (for public subnets)
# -----------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# -----------------------------
# Public Subnets
# -----------------------------
resource "aws_subnet" "public" {
  for_each                = toset(var.public_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = element(var.azs, index(var.public_cidrs, each.value))
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name}-public-${each.key}" })
}

# -----------------------------
# Private Subnets
# -----------------------------
resource "aws_subnet" "private" {
  for_each                = toset(var.private_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = element(var.azs, index(var.private_cidrs, each.value))
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

# -----------------------------
# Public Route Table (connected to IGW)
# -----------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

# Associate all public subnets with the public route table
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------
# Private Route Tables (for NAT Instance routing)
# -----------------------------
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-rt-${each.key}" })
}

# Associate each private subnet with its private route table
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# -----------------------------
# Route from private route tables via NAT Instance
# -----------------------------
# This route will be created in root module (not here),
# but we output the private route table IDs for reference.
# -----------------------------

# -----------------------------
# Outputs
# -----------------------------
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "private_route_table_ids" {
  value = [for rt in aws_route_table.private : rt.id]
}
