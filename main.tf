terraform {
  backend "s3" {
    bucket         = "innovatech-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.24"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "eu-central-1"
}

provider "grafana" {
  url  = "http://${aws_instance.grafana.private_ip}:3000"
  auth = "admin:admin" # pas aan naar je credentials
}