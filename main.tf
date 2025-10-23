#############################################
# Root main.tf — Deploy full infrastructure (NAT Instance)
#############################################

module "vpc" {
  source        = "./modules/vpc"
  vpc_cidr      = var.vpc_cidr
  public_cidrs  = var.public_cidrs
  private_cidrs = var.private_cidrs
  azs           = var.azs
  tags          = var.tags
  name          = var.name
}

#############################################
# NAT Instance (replaces NAT Gateway)
#############################################

# Security group for NAT instance
resource "aws_security_group" "nat_sg" {
  name        = "${var.name}-nat-sg"
  description = "Allow internal traffic and outbound internet access for NAT instance"
  vpc_id      = module.vpc.vpc_id

  # Allow SSH from within the VPC only
  ingress {
    description = "Allow SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound internet access
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-nat-sg" })
}

# NAT Instance
resource "aws_instance" "nat_instance" {
  ami                         = "ami-0b69ea66ff7391e80" # Amazon Linux 2 NAT AMI (us-east-1)
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  associate_public_ip_address = true
  source_dest_check           = false
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]

  tags = merge(var.tags, { Name = "${var.name}-nat-instance" })
}

# Route all private subnets via NAT Instance
resource "aws_route" "private_nat_route" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat_instance.id
  depends_on             = [aws_instance.nat_instance]
}

#############################################
# IAM
#############################################

module "iam" {
  source = "./modules/iam"
  name   = var.name
  tags   = var.tags
}

#############################################
# Jenkins EC2
#############################################

module "jenkins" {
  source               = "./modules/jenkins_instance"
  ami                  = "ami-053b0d53c279acc90" # ✅ Ubuntu 22.04 LTS (us-east-1)
  instance_type        = var.jenkins_instance_type
  private_subnet_ids   = module.vpc.private_subnet_ids
  iam_instance_profile = module.iam.jenkins_instance_profile
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  tags                 = var.tags
  name                 = var.name
}

#############################################
# EKS Cluster
#############################################

module "eks" {
  source              = "./modules/eks"
  cluster_name        = var.name
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired
  tags                = var.tags
}

#############################################
# Outputs
#############################################

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_instance_id" {
  value = aws_instance.nat_instance.id
}

output "nat_instance_public_ip" {
  value = aws_instance.nat_instance.public_ip
}

output "jenkins_private_ip" {
  value = module.jenkins.jenkins_private_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_oidc_provider" {
  value = module.eks.oidc_provider_arn
}
