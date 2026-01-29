terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider configuration
# This will be overridden in each environment
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "aws-landing-zone"
      Repository  = "aws_devops"
    }
  }
}
