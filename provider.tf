terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "remote" {
    organization = "mlsecops"
    workspaces {
      name = "prod"
    }
  }
}

provider "aws" {
  region = var.region
}