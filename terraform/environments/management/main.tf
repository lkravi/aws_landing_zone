# -----------------------------------------------------------------------------
# Management Account Configuration
# This is the primary configuration for the AWS Organization management account
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after bootstrap is complete
  # backend "s3" {
  #   bucket         = "techcorp-terraform-state-ap-southeast-2"
  #   key            = "management/terraform.tfstate"
  #   region         = "ap-southeast-2"
  #   dynamodb_table = "techcorp-terraform-locks"
  #   encrypt        = true
  #   profile        = "techcorp-admin"
  # }
}

provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile

  default_tags {
    tags = {
      ManagedBy    = "terraform"
      Project      = "aws-landing-zone"
      Environment  = "management"
      Organization = var.organization_name
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "techcorp-admin"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "techcorp"
}

variable "create_accounts" {
  description = "Whether to create member accounts (set to true after initial org setup)"
  type        = bool
  default     = false
}

variable "enable_identity_center" {
  description = "Whether to configure IAM Identity Center (must be enabled in AWS Console first)"
  type        = bool
  default     = false
}

variable "create_demo_users" {
  description = "Whether to create demo SSO users (set to true after identity center is enabled)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Email Configuration for Member Accounts
# -----------------------------------------------------------------------------
# SOLUTION: Use Gmail's + alias feature!
#
# If your Gmail is: johnsmith@gmail.com
# You can use:
#   johnsmith+aws-security@gmail.com
#   johnsmith+aws-logs@gmail.com
#   etc.
#
# ALL emails go to your single Gmail inbox - no extra accounts needed!
# This works with most email providers (Gmail, Outlook, Yahoo, etc.)
# -----------------------------------------------------------------------------

variable "base_email" {
  description = "Your base email address (e.g., yourname@gmail.com)"
  type        = string
  default     = ""  # Set this to your email!
}

locals {
  # Automatically generate account emails from base email
  # If base_email is "john@gmail.com", this creates "john+aws-security@gmail.com"
  email_parts = var.base_email != "" ? split("@", var.base_email) : ["", ""]
  email_user  = local.email_parts[0]
  email_domain = length(local.email_parts) > 1 ? local.email_parts[1] : ""

  generated_emails = var.base_email != "" ? {
    security_tooling    = "${local.email_user}+aws-security@${local.email_domain}"
    log_archive         = "${local.email_user}+aws-logs@${local.email_domain}"
    network_hub         = "${local.email_user}+aws-network@${local.email_domain}"
    shared_services     = "${local.email_user}+aws-shared@${local.email_domain}"
    prod_engineering    = "${local.email_user}+aws-prod-eng@${local.email_domain}"
    prod_data           = "${local.email_user}+aws-prod-data@${local.email_domain}"
    dev_engineering     = "${local.email_user}+aws-dev-eng@${local.email_domain}"
    staging_engineering = "${local.email_user}+aws-staging@${local.email_domain}"
    sandbox_engineering = "${local.email_user}+aws-sandbox@${local.email_domain}"
  } : {}
}

variable "account_emails" {
  description = "Email addresses for member accounts (leave empty to auto-generate from base_email)"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# AWS Organizations
# -----------------------------------------------------------------------------

module "organization" {
  source = "../../modules/organization"

  organization_name = var.organization_name
  create_accounts   = var.create_accounts
  # Use provided emails or auto-generated from base_email
  account_emails    = length(var.account_emails) > 0 ? var.account_emails : local.generated_emails
}

# -----------------------------------------------------------------------------
# IAM Identity Center
# NOTE: IAM Identity Center must be enabled in AWS Console first!
# Go to: AWS Console > IAM Identity Center > Enable
# Then set enable_identity_center = true
# -----------------------------------------------------------------------------

module "identity_center" {
  source = "../../modules/identity-center"
  count  = var.enable_identity_center ? 1 : 0

  # Don't assign to accounts until accounts are created
  assign_to_accounts = var.create_accounts

  management_account_id = data.aws_caller_identity.current.account_id

  security_account_ids = var.create_accounts ? {
    security_tooling = module.organization.account_ids["security_tooling"]
    log_archive      = module.organization.account_ids["log_archive"]
  } : {}

  infrastructure_account_ids = var.create_accounts ? {
    network_hub     = module.organization.account_ids["network_hub"]
    shared_services = module.organization.account_ids["shared_services"]
  } : {}

  workload_account_ids = var.create_accounts ? module.organization.account_ids : {}

  prod_account_ids = var.create_accounts ? {
    prod_engineering = module.organization.account_ids["prod_engineering"]
    prod_data        = module.organization.account_ids["prod_data"]
  } : {}

  nonprod_account_ids = var.create_accounts ? {
    dev_engineering     = module.organization.account_ids["dev_engineering"]
    staging_engineering = module.organization.account_ids["staging_engineering"]
  } : {}

  dev_account_ids = var.create_accounts ? {
    dev_engineering = module.organization.account_ids["dev_engineering"]
  } : {}

  sandbox_account_ids = var.create_accounts ? {
    sandbox_engineering = module.organization.account_ids["sandbox_engineering"]
  } : {}

  data_account_ids = var.create_accounts ? {
    prod_data = module.organization.account_ids["prod_data"]
  } : {}

  # Demo users configuration
  create_demo_users = var.create_demo_users
  base_email        = var.base_email

  depends_on = [module.organization]
}

# -----------------------------------------------------------------------------
# Organization CloudTrail
# -----------------------------------------------------------------------------

module "cloudtrail" {
  source = "../../modules/security/cloudtrail"

  name_prefix                   = var.organization_name
  trail_name                    = "${var.organization_name}-organization-trail"
  log_retention_days            = 365
  enable_cloudwatch_logs        = true
  cloudwatch_log_retention_days = 30

  tags = {
    Component = "security"
  }

  depends_on = [module.organization]
}

# -----------------------------------------------------------------------------
# GuardDuty
# -----------------------------------------------------------------------------

module "guardduty" {
  source = "../../modules/security/guardduty"

  name_prefix                  = var.organization_name
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  enable_kubernetes_audit_logs = true
  enable_malware_protection    = true
  create_findings_bucket       = true
  create_sns_topic             = true

  # Delegate to security account after it's created
  # Note: enable_delegated_admin must be a known boolean at plan time
  enable_delegated_admin     = var.create_accounts
  delegated_admin_account_id = var.create_accounts ? module.organization.account_ids["security_tooling"] : ""

  tags = {
    Component = "security"
  }

  depends_on = [module.organization]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organization.organization_id
}

output "organization_root_id" {
  description = "AWS Organization Root ID"
  value       = module.organization.organization_root_id
}

output "management_account_id" {
  description = "Management Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "ou_ids" {
  description = "Organizational Unit IDs"
  value       = module.organization.ou_ids
}

output "account_ids" {
  description = "Member Account IDs"
  value       = module.organization.account_ids
}

output "sso_start_url" {
  description = "IAM Identity Center Start URL"
  value       = var.enable_identity_center ? module.identity_center[0].sso_start_url : "IAM Identity Center not enabled"
}

output "sso_groups" {
  description = "IAM Identity Center Group IDs"
  value       = var.enable_identity_center ? module.identity_center[0].group_ids : {}
}

output "sso_demo_users" {
  description = "Demo SSO users (check email for password setup link)"
  value       = var.enable_identity_center && var.create_demo_users ? module.identity_center[0].demo_users : {}
}

output "cloudtrail_bucket" {
  description = "CloudTrail S3 Bucket"
  value       = module.cloudtrail.s3_bucket_name
}

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = module.guardduty.detector_id
}

output "generated_account_emails" {
  description = "Auto-generated email addresses for member accounts"
  value       = local.generated_emails
}
