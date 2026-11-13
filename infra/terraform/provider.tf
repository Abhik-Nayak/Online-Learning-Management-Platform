# Terraform + AWS provider configuration.
# Credentials are NOT stored here: the provider reads them from
# ~/.aws/credentials, created by `aws configure` on the Management Server.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # pinned to the 6.x major version
    }
  }
}

provider "aws" {
  region = var.region

  # These tags are added to every resource Terraform creates.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
