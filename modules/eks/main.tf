##########################################
# IAM roles for EKS control plane & nodes
##########################################

resource "aws_iam_role" "cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  ])
  role       = aws_iam_role.cluster_role.name
  policy_arn = each.value
}

resource "aws_iam_role" "node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
  role       = aws_iam_role.node_role.name
  policy_arn = each.value
}

##########################################
# EKS Cluster
##########################################
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn

  version = var.k8s_version

  vpc_config {
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # Wait for IAM attachments first
  depends_on = [aws_iam_role_policy_attachment.cluster_policies]
}

##########################################
# Optional: create OIDC provider for IRSA
##########################################
resource "aws_iam_openid_connect_provider" "this" {
  count = var.create_oidc ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10df6"]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  depends_on = [aws_eks_cluster.this]
}


##########################################
# Managed Node Group
##########################################
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  disk_size = var.node_disk_size

  tags = var.tags

  depends_on = [aws_eks_cluster.this]
}

##########################################
# IRSA roles for ALB controller and Jenkins deployer
##########################################

# Option A: create ALB controller policy in this module if the JSON is provided
resource "aws_iam_policy" "alb_controller_policy" {
  count = (var.alb_controller_policy_arn == "" && length(trim(var.alb_controller_policy_document, " ")) > 0) ? 1 : 0
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller (created by terraform module)"
  policy      = var.alb_controller_policy_document
}

# Determine which ALB policy ARN to attach
locals {
  alb_policy_arn = var.alb_controller_policy_arn != "" ? var.alb_controller_policy_arn : (length(aws_iam_policy.alb_controller_policy) > 0 ? aws_iam_policy.alb_controller_policy[0].arn : null)
}


# ALB controller IRSA role (assumable by service account in kube-system/aws-load-balancer-controller)
resource "aws_iam_role" "alb_irsa_role" {
  count = var.create_alb_irsa ? 1 : 0

  name = "${var.cluster_name}-alb-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.this[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer,"https://","")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
  tags = var.tags
  depends_on = [aws_iam_openid_connect_provider.this]
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  count = var.create_alb_irsa && local.alb_policy_arn != null ? 1 : 0

  role       = aws_iam_role.alb_irsa_role[0].name
  policy_arn = local.alb_policy_arn
}

# Jenkins deployer IRSA role (service account: default/jenkins-deployer)
resource "aws_iam_role" "jenkins_irsa_role" {
  count = var.create_jenkins_irsa ? 1 : 0

  name = "${var.cluster_name}-jenkins-deployer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.this[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer,"https://","")}:sub" = "system:serviceaccount:default:jenkins-deployer"
          }
        }
      }
    ]
  })
  tags = var.tags

  depends_on = [aws_iam_openid_connect_provider.this]
}

# Optionally attach managed policies to Jenkins deployer role
resource "aws_iam_role_policy_attachment" "jenkins_deployer_attach" {
  count = var.create_jenkins_irsa ? length(var.jenkins_deployer_managed_policy_arns) : 0

  role       = aws_iam_role.jenkins_irsa_role[0].name
  policy_arn = var.jenkins_deployer_managed_policy_arns[count.index]
}


# =========================================================
# Attach EKS + ECR access policies to Jenkins EC2 role
# =========================================================

# Attach required AWS managed policies to the Jenkins role
resource "aws_iam_role_policy_attachment" "jenkins_eks_access" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  role       = var.jenkins_role_name
  policy_arn = each.value
}
