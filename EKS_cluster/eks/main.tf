resource "aws_iam_role" "EKSrole" {
  name = "eks-cluster-demo"

  assume_role_policy = jsonencode(
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
})
}

resource "aws_iam_role_policy_attachment" "demo-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.EKSrole.name
}

# resource "aws_iam_role_policy_attachment" "demo-AmazonEKSServiceRolePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonEKSServiceRolePolicy"
#   role       = aws_iam_role.EKSrole.name
# }

resource "aws_eks_cluster" "EKSwithTF" {
  name = "ClusterWithTF"
  role_arn = aws_iam_role.EKSrole.arn

  vpc_config {
    subnet_ids = [
        local.PrivateSubnet1-id,
        local.PrivateSubnet2-id,
        local.PublicSubnet1-id,
        local.PublicSubnet2-id
    ]
  }

  depends_on = [ aws_iam_role_policy_attachment.demo-AmazonEKSClusterPolicy ]
}

resource "aws_iam_role" "nodesForEKS" {
  assume_role_policy = jsonencode(
  {
    "Version" = "2012-10-17"
    "Statement" = [
    {
      "Effect" = "Allow"
      Principal = {
        "Service" = "ec2.amazonaws.com"
      }
      "Action" = "sts:AssumeRole"
    }
  ]
})
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodesForEKS.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodesForEKS.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodesForEKS.name
}

resource "aws_eks_node_group" "private-nodes-for-EKS" {
  cluster_name = aws_eks_cluster.EKSwithTF.name
  node_group_name = "private-nodes-for-EKS"
  node_role_arn = aws_iam_role.nodesForEKS.arn
  subnet_ids = [ 
    local.PrivateSubnet1-id,
    local.PrivateSubnet2-id
  ]
  scaling_config {
    desired_size = 2
    max_size = 2
    min_size = 2
  }
  capacity_type = "ON_DEMAND"
  instance_types = ["t2.micro"]

  update_config {
    max_unavailable = 1
  }

  depends_on = [ 
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy
   ]
}

data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "/home/srujan/Projects/terraform_projects/EKS_cluster/EKS_cluster/vpc/terraform.tfstate"
  }
}

locals {
  PrivateSubnet1-id = data.terraform_remote_state.vpc.outputs.PrivateSubnet1-id
  PrivateSubnet2-id = data.terraform_remote_state.vpc.outputs.PrivateSubnet2-id
  PublicSubnet1-id = data.terraform_remote_state.vpc.outputs.PublicSubnet1-id
  PublicSubnet2-id = data.terraform_remote_state.vpc.outputs.PublicSubnet2-id
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.EKSwithTF.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.EKSwithTF.identity[0].oidc[0].issuer
}
