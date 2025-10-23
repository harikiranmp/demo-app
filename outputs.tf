output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_instance_public_ip" {
  description = "Public IP of the NAT instance"
  value       = aws_instance.nat_instance.public_ip
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
