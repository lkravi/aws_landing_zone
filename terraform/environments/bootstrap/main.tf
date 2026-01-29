# -----------------------------------------------------------------------------
# Bootstrap Configuration
# This creates the S3 bucket and DynamoDB table for Terraform state management
# Run this FIRST before any other Terraform configurations
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Initial apply uses local state, then migrate to S3
  # After first apply, uncomment the backend block and run terraform init -migrate-state
  # backend "s3" {
  #   bucket         = "techcorp-terraform-state-ap-southeast-2"
  #   key            = "bootstrap/terraform.tfstate"
  #   region         = "ap-southeast-2"
  #   dynamodb_table = "techcorp-terraform-locks"
  #   encrypt        = true
  #   profile        = "techcorp-admin"
  # }
}

# -----------------------------------------------------------------------------
# IMPORTANT: AWS Profile Configuration
# -----------------------------------------------------------------------------
# This project uses a dedicated AWS profile to avoid conflicts with personal
# AWS credentials. Before running Terraform, set up the profile:
#
# 1. Create new AWS account (this will be your Management Account)
# 2. Create IAM user with AdministratorAccess (temporary, for initial setup)
# 3. Configure AWS CLI profile:
#
#    aws configure --profile techcorp-admin
#
# 4. Set environment variable (optional, recommended):
#    export AWS_PROFILE=techcorp-admin
#
# Or pass the profile via variable:
#    terraform apply -var="aws_profile=techcorp-admin"
# -----------------------------------------------------------------------------

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      ManagedBy  = "terraform"
      Project    = "aws-landing-zone"
      Component  = "bootstrap"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "aws_profile" {
  description = "AWS CLI profile to use (isolates this project from personal credentials)"
  type        = string
  default     = "techcorp-admin"
}

variable "region" {
  description = "AWS region for state bucket"
  type        = string
  default     = "ap-southeast-2"
}

variable "organization_name" {
  description = "Organization name prefix"
  type        = string
  default     = "techcorp"
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# S3 Bucket for Terraform State
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.organization_name}-terraform-state-${var.region}"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  tags = {
    Name        = "${var.organization_name}-terraform-state"
    Purpose     = "Terraform state storage"
    Environment = "management"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }
}

# -----------------------------------------------------------------------------
# KMS Key for State Encryption
# -----------------------------------------------------------------------------

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.organization_name}-terraform-state-key"
    Purpose = "Terraform state encryption"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.organization_name}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# -----------------------------------------------------------------------------
# DynamoDB Table for State Locking
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.organization_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.organization_name}-terraform-locks"
    Purpose     = "Terraform state locking"
    Environment = "management"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key for state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "backend_config" {
  description = "Backend configuration to use in other Terraform configurations"
  value = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "<component>/terraform.tfstate"
      region         = "${var.region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
      encrypt        = true
      kms_key_id     = "${aws_kms_key.terraform_state.arn}"
      profile        = "${var.aws_profile}"
    }
  EOT
}

output "aws_profile_reminder" {
  description = "Reminder about AWS profile usage"
  value = <<-EOT

    ============================================================
    IMPORTANT: This project uses AWS profile: ${var.aws_profile}

    Before running Terraform commands, ensure you have configured
    the AWS CLI profile or set the environment variable:

      export AWS_PROFILE=${var.aws_profile}

    Or pass it to terraform:

      terraform apply -var="aws_profile=${var.aws_profile}"
    ============================================================
  EOT
}
