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
  #key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]

  tags = merge(var.tags, { Name = "${var.name}-nat-instance" })
}

# Route all private subnets via NAT Instance
resource "aws_route" "private_nat_route" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
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
  jenkins_role_name   = module.iam.jenkins_role_name
}

#############################################
# Public ALB for Jenkins (accessible via browser)
#############################################

# Security group for ALB
resource "aws_security_group" "jenkins_alb_sg" {
  name        = "${var.name}-jenkins-alb-sg"
  description = "Security group for Jenkins ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-jenkins-alb-sg" })
}

# Application Load Balancer
resource "aws_lb" "jenkins_alb" {
  name               = "${var.name}-jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins_alb_sg.id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, { Name = "${var.name}-jenkins-alb" })
}

# Target Group for Jenkins
resource "aws_lb_target_group" "jenkins_tg" {
  name        = "${var.name}-jenkins-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    path                = "/login"
    port                = "8080"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = merge(var.tags, { Name = "${var.name}-jenkins-tg" })
}

# Attach Jenkins instance to target group
resource "aws_lb_target_group_attachment" "jenkins_tg_attach" {
  target_group_arn = aws_lb_target_group.jenkins_tg.arn
  target_id        = module.jenkins.jenkins_instance_id
  port             = 8080
}

# ALB Listener on port 80 (HTTP)
resource "aws_lb_listener" "jenkins_listener" {
  load_balancer_arn = aws_lb.jenkins_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_tg.arn
  }
}

# Output ALB DNS Name
output "jenkins_alb_dns_name" {
  description = "Public DNS of Jenkins ALB"
  value       = aws_lb.jenkins_alb.dns_name
}

