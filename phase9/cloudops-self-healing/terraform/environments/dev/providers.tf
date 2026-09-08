terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Remote state in S3, with Terraform's native S3 locking
  # (use_lockfile — available in Terraform 1.10+). This replaces the
  # older DynamoDB-table-based locking pattern; no separate lock table
  # needs to be created or managed.
  #
  # NOTE: this S3 bucket must already exist before `terraform init`
  # will work — see the bootstrap step in docs/deployment.md / Phase 3
  # instructions. Terraform cannot create the bucket it's about to
  # store its own state in (chicken-and-egg problem).
  backend "s3" {
    bucket       = "REPLACE-ME-cloudops-tfstate-<your-account-id>"
    key          = "cloudops-self-healing/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
