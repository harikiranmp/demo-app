variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "jenkins_role_name" {
  description = "IAM role name for Jenkins EC2"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version for EKS control plane"
  type        = string
  default     = "1.33"
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDRs allowed for public cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable private API endpoint"
  type        = bool
  default     = false
}

variable "node_instance_types" {
  description = "EKS worker instance types (managed nodegroup)"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Max number of nodes"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Min number of nodes"
  type        = number
  default     = 1
}

variable "node_disk_size" {
  description = "Root disk size for nodes (GB)"
  type        = number
  default     = 20
}

variable "create_oidc" {
  description = "Create (associate) an IAM OIDC provider for the cluster"
  type        = bool
  default     = true
}

variable "oidc_thumbprint_list" {
  description = "Thumbprint list for the OIDC provider (if empty, a common thumbprint will be used)"
  type        = list(string)
  default     = []
}

variable "create_alb_irsa" {
  description = "Create IRSA role for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "alb_controller_policy_arn" {
  description = "Pre-created ARN of AWSLoadBalancerControllerIAMPolicy (if you created it outside Terraform)"
  type        = string
  default     = ""
}

variable "alb_controller_policy_document" {
  description = "If you want Terraform to create the ALB controller IAM policy inline (pass the JSON here)"
  type        = string
  default     = ""
}

variable "create_jenkins_irsa" {
  description = "Create IRSA role for Jenkins deployer service account"
  type        = bool
  default     = true
}

variable "jenkins_deployer_managed_policy_arns" {
  description = "Managed policies to attach to Jenkins deployer IRSA role (list of ARNs)"
  type        = list(string)
  default     = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy", # example, change as needed
  ]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
