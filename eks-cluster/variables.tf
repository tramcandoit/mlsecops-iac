variable "region"{
  type = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "CIDR block for VPC"
}

variable "public_subnet_cidr" {
  type        = list(string)
  default     = ["192.168.1.0/24", "192.168.4.0/24"]
  description = "CIDR block for Public Subnets"
}

variable "private_subnet_cidr" {
  type        = list(string)
  default     = ["192.168.2.0/24", "192.168.3.0/24"]
  description = "CIDR block for Private Subnets"
}

variable "az_public" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "AZ for Public Subnets"
}

variable "az_private" {
  type        = list(string)
  default     = ["us-east-1a","us-east-1b"]
  description = "AZ for Private Subnets"
}

variable "security_groups" {
  type = list(object({
    name        = string
    description = string
    ingress = list(object({
      description      = string
      protocol         = string
      from_port        = number
      to_port          = number
      cidr_blocks      = list(string)
      ipv6_cidr_blocks = list(string)
    }))
    egress = list(object({
      description      = string
      protocol         = string
      from_port        = number
      to_port          = number
      cidr_blocks      = list(string)
      ipv6_cidr_blocks = list(string)
    }))
  }))
  default = [{
    name        = "custom-security-group"
    description = "Inbound & Outbound traffic for custom-security-group"
    ingress = [
      {
        description      = "Allow HTTPS"
        protocol         = "tcp"
        from_port        = 443
        to_port          = 443
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = null
      },
      {
        description      = "Allow HTTP"
        protocol         = "tcp"
        from_port        = 80
        to_port          = 80
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = null
      },
    ]
    egress = [
      {
        description      = "Allow all outbound traffic"
        protocol         = "-1"
        from_port        = 0
        to_port          = 0
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
      }
    ]
  }]
}

variable "cluster_config" {
  type = object({
    name    = string
    version = string
  })
  default = {
    name    = "mlsecops-eks-cluster"
    version = "1.31"
  }
}

variable "node_groups" {
  type = list(object({
    name           = string
    instance_types = list(string)
    ami_type       = string
    capacity_type  = string
    disk_size      = number
    scaling_config = object({
      desired_size = number
      min_size     = number
      max_size     = number
    })
    update_config = object({
      max_unavailable = number
    })
  }))
  default = [
    {
      name           = "t3-medium-standard"
      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
      disk_size      = 10
      scaling_config = {
        desired_size = 1
        max_size     = 3
        min_size     = 1
      }
      update_config = {
        max_unavailable = 1
      }
    },
    {
      name           = "t3-medium-spot"
      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64"
      capacity_type  = "SPOT"
      disk_size      = 10
      scaling_config = {
        desired_size = 1
        max_size     = 3
        min_size     = 1
      }
      update_config = {
        max_unavailable = 1
      }
    },
  ]

}

variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
  default = [
   {
      name    = "kube-proxy"
      version = "v1.30.6-eksbuild.3"
    },
    {
      name    = "vpc-cni"
      version = "v1.19.0-eksbuild.1"
    },
    {
      name    = "coredns"
      version = "v1.11.3-eksbuild.1"
    },
    {
      name    = "aws-ebs-csi-driver"
      version = "v1.37.0-eksbuild.1"
    },
    {
      name    = "eks-pod-identity-agent"
      version = "v1.2.0-eksbuild.1"
    }
  ]
}

#### RDS variables ####

variable "rds" {
  description = "RDS PostgreSQL settings"
  type = object({
    instance_class  = string
    allocated_gb    = number
    max_allocated_gb= number
    db_name         = string
    username        = string
    multi_az        = bool
    port            = number
    backup_retention= number
  })
  default = {
    instance_class   = "db.t3.small"
    allocated_gb     = 20
    max_allocated_gb = 25
    db_name          = "mlflowbackend"
    username         = "mlflowadmin"
    multi_az         = false
    port             = 5432
    backup_retention = 7
  }
}

variable "rds_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master password"
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:625715126488:secret:mlflow/backend/psqlpassword-jGhk1B"
}
