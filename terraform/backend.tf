# =============================================================================
# TERRAFORM & PROVIDER CONFIGURATION
# =============================================================================
# - Defines the minimum Terraform version
# - Locks the AWS provider to a compatible version range
# - Configures the S3 remote backend so state is never lost or corrupted
# - Sets default tags on every resource for cost tracking and organization
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state stored in S3 — if we lose our laptop, we don't lose the state.
  # DynamoDB table (provided separately) enables state locking to prevent
  # two people from running terraform apply at the same time.
  backend "s3" {
    bucket  = "devops-terraform-state-183088117731"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # dynamodb_table is omitted — solo project, no concurrent applies
  }
}

# Provider block — ALL resources will be created in us-east-1 unless overridden
provider "aws" {
  region = var.region

  # Default tags are applied to every resource that supports tagging.
  # Without these, identifying which resources belong to this project
  # in the AWS console would be tedious.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
