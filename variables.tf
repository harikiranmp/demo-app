variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Application name prefix"
  type        = string
  default     = "sample-app"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_cidrs" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "jenkins_ami" {
  description = "Ubuntu 24.04 AMI for Jenkins"
  type        = string
  default     = "ami-0360c520857e3138f"
}

variable "jenkins_instance_type" {
  description = "Jenkins EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_instance_types" {
  description = "EKS worker node instance types"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "ecr_repo_name" {
  description = "ECR repo name for the app"
  type        = string
  default     = "sample-app-repo"
}

variable "key_name" {
  description = "Name of the EC2 key pair used for SSH access"
  type        = string
  default     = "my-key" # Change to your actual AWS key pair
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Owner = "dinesh"
  }
}
