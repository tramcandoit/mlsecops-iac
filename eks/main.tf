locals {
  project_name = "mlsecops"
}

#---------------------------------------------------------------#
#----------------- Create 1 VPC with 2 subnets -----------------#
#---------------------------------------------------------------#

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${local.project_name}-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count      = length(var.public_subnet_cidr)
  cidr_block = element(var.public_subnet_cidr, count.index)
  tags = {
    Name = "${local.project_name}-public-subnet"
  }
  depends_on = [aws_vpc.vpc]
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count      = length(var.private_subnet_cidr)
  cidr_block = element(var.private_subnet_cidr, count.index + 1)

  tags = {
    Name = "${local.project_name}-private-subnet"
  }
}

#---------------------------------------------------------------#
#------------------ Create 1 Internet Gateway ------------------#
#--------------------- Attach IGW to VPC -----------------------#
#---------------------------------------------------------------#

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.project_name}-igw"
  }
}

#---------------------------------------------------------------#
#---------------- Create Default Security Group ----------------#
#---------------------------------------------------------------#

resource "aws_default_security_group" "default-sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name}-default-sg"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id
  tags = {
    Name = "${local.project_name}-natgw"
  }
}

#---------------------------------------------------------------#
#------------------ Create Public Route Table ------------------#
#------------------------ Route to IGW -------------------------#
#---------------------------------------------------------------#

resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Destination cidr block
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.project_name}-public_rtb"
  }
}

#---------------------------------------------------------------#
#------------------ Create Private Route Table -----------------#
#----------------------- Route to NATGW ------------------------#
#---------------------------------------------------------------#

resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "${local.project_name}-private_rtb"
  }
}

#---------------------------------------------------------------#
#----------------- Associate Public Route Table ----------------#
#--------------------- to public Subnet ------------------------#
#---------------------------------------------------------------#

resource "aws_route_table_association" "public_rtb_asso" {
  subnet_id      = aws_subnet.public_subnet[0].id
  route_table_id = aws_route_table.public_rtb.id
}

#---------------------------------------------------------------#
#---------------- Associate Private Route Table ----------------#
#--------------------- to private Subnet -----------------------#
#---------------------------------------------------------------#

resource "aws_route_table_association" "private_rtb_asso" {
  subnet_id      = aws_subnet.private_subnet[0].id
  route_table_id = aws_route_table.private_rtb.id
}

# SECURITY GROUPS
resource "aws_security_group" "sec_groups" {
  for_each    = { for sec in var.security_groups : sec.name => sec }
  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = try(each.value.ingress, [])
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = try(each.value.egress, [])
    content {
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
    }
  }
}

# EKS Cluster
resource "aws_eks_cluster" "eks-cluster" {
  name     = var.cluster_config.name
  role_arn = aws_iam_role.EKSClusterRole.arn
  version  = var.cluster_config.version

  vpc_config {
    subnet_ids = flatten([
      aws_subnet.public_subnet[*].id,
      aws_subnet.private_subnet[*].id
    ])
    security_group_ids = [
      aws_default_security_group.default-sg.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy
  ]

  enabled_cluster_log_types = ["api", "audit", "authenticator","controllerManager","scheduler"]

}

# NODE GROUP
resource "aws_eks_node_group" "node-ec2" {
  for_each        = { for node_group in var.node_groups : node_group.name => node_group }
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.NodeGroupRole.arn
  subnet_ids      = aws_subnet.private_subnet[*].id

  scaling_config {
    desired_size = try(each.value.scaling_config.desired_size, 1)
    max_size     = try(each.value.scaling_config.max_size, 3)
    min_size     = try(each.value.scaling_config.min_size, 1)
  }

  update_config {
    max_unavailable = try(each.value.update_config.max_unavailable, 1)
  }

  ami_type       = each.value.ami_type
  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy
  ]
}

resource "aws_eks_addon" "addons" {
  for_each          = { for addon in var.addons : addon.name => addon }
  cluster_name      = aws_eks_cluster.eks-cluster.id
  addon_name        = each.value.name
  addon_version     = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_iam_openid_connect_provider" "default" {
  url             = "https://${local.oidc}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}