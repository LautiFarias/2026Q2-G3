terraform {
  required_version = ">= 1.10"

  backend "s3" {
    # Los valores reales vienen de infra/backend.hcl (generado por bootstrap/)
    # pasado con: terraform init -backend-config=backend.hcl
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region
}
