###############################################################################
# providers.tf  —  Terraform + AWS provider configuration
#
# Pins Terraform and AWS provider versions for reproducible deployments.
# The bucket/dynamodb backend block below is commented out: enable it once a
# shared state bucket exists. During portfolio grading the default local
# backend is sufficient.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # --- Optional remote state (enable for team / production use) -------------
  # backend "s3" {
  #   bucket         = "frank-cloudprog-tfstate"
  #   key            = "task1/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "frank-cloudprog-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Frank Masabo"
      Course      = "DLBSEPCP01_E"
    }
  }
}

# Aliased provider for CloudFront + WAF (scope=CLOUDFRONT must be us-east-1).
provider "aws" {
  alias  = "useast1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Frank Masabo"
      Course      = "DLBSEPCP01_E"
    }
  }
}
