# terraform.tfvars
aws_region = "us-east-1"
name       = "demo-app"
vpc_cidr   = "10.0.0.0/16"
public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
azs           = ["us-east-1a", "us-east-1b"]
jenkins_instance_type = "t3.small"
eks_node_instance_types = ["t3.small"]
eks_node_desired = 2
#key_name = "my-key"
tags = {
  Owner = "Hari"
}
