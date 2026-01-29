# -----------------------------------------------------------------------------
# AWS Organizations Module
# Creates the organization structure with OUs and accounts
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Organization
# -----------------------------------------------------------------------------

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "access-analyzer.amazonaws.com",
    "account.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "inspector2.amazonaws.com",
    "malware-protection.guardduty.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
    "ram.amazonaws.com",
    "securityhub.amazonaws.com",
    "servicecatalog.amazonaws.com",
    "sso.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
    "BACKUP_POLICY",
  ]

  feature_set = "ALL"
}

# -----------------------------------------------------------------------------
# Organizational Units (OUs)
# -----------------------------------------------------------------------------

# Root-level OUs
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id

  tags = {
    Description = "Security and compliance accounts"
    ManagedBy   = "terraform"
  }
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id

  tags = {
    Description = "Shared infrastructure accounts"
    ManagedBy   = "terraform"
  }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id

  tags = {
    Description = "Workload accounts for all environments"
    ManagedBy   = "terraform"
  }
}

resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = aws_organizations_organization.this.roots[0].id

  tags = {
    Description = "Suspended and decommissioned accounts"
    ManagedBy   = "terraform"
  }
}

# Workloads child OUs
resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Description = "Production workload accounts"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_organizations_organizational_unit" "non_production" {
  name      = "Staging"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Description = "Non-production accounts for dev and staging"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}

resource "aws_organizations_organizational_unit" "experimental" {
  name      = "Experimental"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = {
    Description = "Sandbox and experimental accounts"
    Environment = "experimental"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Member Accounts
# Note: Account creation via Terraform is a one-way operation.
# Accounts cannot be deleted via Terraform - they must be manually closed.
# -----------------------------------------------------------------------------

# Security Accounts
resource "aws_organizations_account" "security_tooling" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-security-tooling"
  email     = var.account_emails["security_tooling"]
  parent_id = aws_organizations_organizational_unit.security.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "security"
    Purpose     = "Security tooling - GuardDuty and Security Hub"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "log_archive" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-log-archive"
  email     = var.account_emails["log_archive"]
  parent_id = aws_organizations_organizational_unit.security.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "security"
    Purpose     = "Centralized log archive"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

# Infrastructure Accounts
resource "aws_organizations_account" "network_hub" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-network-hub"
  email     = var.account_emails["network_hub"]
  parent_id = aws_organizations_organizational_unit.infrastructure.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "infrastructure"
    Purpose     = "Network hub - Transit Gateway and DNS"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "shared_services" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-shared-services"
  email     = var.account_emails["shared_services"]
  parent_id = aws_organizations_organizational_unit.infrastructure.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "infrastructure"
    Purpose     = "Shared services - CICD and ECR"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

# Production Accounts
resource "aws_organizations_account" "prod_engineering" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-prod-engineering"
  email     = var.account_emails["prod_engineering"]
  parent_id = aws_organizations_organizational_unit.production.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "production"
    Department  = "engineering"
    Purpose     = "Production workloads - Engineering"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "prod_data" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-prod-data"
  email     = var.account_emails["prod_data"]
  parent_id = aws_organizations_organizational_unit.production.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "production"
    Department  = "data-science"
    Purpose     = "Production workloads - Data Science"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

# Non-Production Accounts
resource "aws_organizations_account" "dev_engineering" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-dev-engineering"
  email     = var.account_emails["dev_engineering"]
  parent_id = aws_organizations_organizational_unit.non_production.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "development"
    Department  = "engineering"
    Purpose     = "Development workloads - Engineering"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "staging_engineering" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-staging-engineering"
  email     = var.account_emails["staging_engineering"]
  parent_id = aws_organizations_organizational_unit.non_production.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "staging"
    Department  = "engineering"
    Purpose     = "Staging workloads - Engineering"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

# Sandbox Accounts
resource "aws_organizations_account" "sandbox_engineering" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-sandbox-engineering"
  email     = var.account_emails["sandbox_engineering"]
  parent_id = aws_organizations_organizational_unit.experimental.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "sandbox"
    Department  = "engineering"
    Purpose     = "Sandbox for experimentation"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}
