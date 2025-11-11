data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "eks-cluster" {
  name = aws_eks_cluster.eks-cluster.name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks-cluster.name
}

data "aws_secretsmanager_secret" "rds_master" {
  arn = var.rds_secret_arn
}

data "aws_secretsmanager_secret_version" "rds_master_v" {
  secret_id = data.aws_secretsmanager_secret.rds_master.id
}


locals {
  oidc = trimprefix(data.aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer, "https://")
}