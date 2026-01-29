# -----------------------------------------------------------------------------
# IAM Identity Center Module
# Manages centralized identity and access across AWS accounts
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
# Data Sources
# -----------------------------------------------------------------------------

data "aws_ssoadmin_instances" "this" {}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
}

# -----------------------------------------------------------------------------
# Permission Sets
# These define the IAM policies that will be assigned to users/groups
# -----------------------------------------------------------------------------

# Administrator Access - Full access to all AWS services
resource "aws_ssoadmin_permission_set" "administrator" {
  name             = "AdministratorAccess"
  description      = "Full administrator access to AWS account"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H" # 4 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Full admin access"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
}

# Power User Access - Full access except IAM
resource "aws_ssoadmin_permission_set" "power_user" {
  name             = "PowerUserAccess"
  description      = "Full access to AWS services except IAM"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Power user access without IAM"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "power_user" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn
}

# Developer Access - Common developer permissions
resource "aws_ssoadmin_permission_set" "developer" {
  name             = "DeveloperAccess"
  description      = "Developer access for application deployment and debugging"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Developer access"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DeveloperEC2Access"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:CreateTags",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperS3Access"
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperLambdaAccess"
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperECSAccess"
        Effect = "Allow"
        Action = [
          "ecs:*",
          "ecr:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperCloudWatchAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperAPIGatewayAccess"
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperDynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperSNSSQSAccess"
        Effect = "Allow"
        Action = [
          "sns:*",
          "sqs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeveloperSecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Read Only Access
resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "ReadOnlyAccess"
  description      = "Read-only access to AWS resources"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT12H" # 12 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "View only access"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
}

# Data Scientist Access
resource "aws_ssoadmin_permission_set" "data_scientist" {
  name             = "DataScientistAccess"
  description      = "Access for data science workloads (SageMaker, EMR, Athena, Glue)"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Data science access"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "data_scientist_sagemaker" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  permission_set_arn = aws_ssoadmin_permission_set.data_scientist.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "data_scientist" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_scientist.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DataScienceAnalyticsAccess"
        Effect = "Allow"
        Action = [
          "athena:*",
          "glue:*",
          "emr:*",
          "emr-serverless:*",
          "redshift:*",
          "redshift-serverless:*",
          "quicksight:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DataScienceS3Access"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::*-data-*",
          "arn:aws:s3:::*-data-*/*",
          "arn:aws:s3:::*-ml-*",
          "arn:aws:s3:::*-ml-*/*"
        ]
      }
    ]
  })
}

# Security Auditor Access
resource "aws_ssoadmin_permission_set" "security_auditor" {
  name             = "SecurityAuditAccess"
  description      = "Security audit and compliance review access"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H" # 4 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Security audit"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "security_auditor" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor.arn
}

# Billing Access
resource "aws_ssoadmin_permission_set" "billing" {
  name             = "BillingAccess"
  description      = "Access to billing and cost management"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H" # 4 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Billing and cost management"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "billing" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
  permission_set_arn = aws_ssoadmin_permission_set.billing.arn
}

# Network Admin Access
resource "aws_ssoadmin_permission_set" "network_admin" {
  name             = "NetworkAdminAccess"
  description      = "Network administration access (VPC, TGW, Route53)"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours

  tags = {
    ManagedBy = "terraform"
    Purpose   = "Network administration"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "network_admin" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/NetworkAdministrator"
  permission_set_arn = aws_ssoadmin_permission_set.network_admin.arn
}

# -----------------------------------------------------------------------------
# Groups
# These groups organize users and are assigned to accounts with permission sets
# -----------------------------------------------------------------------------

resource "aws_identitystore_group" "platform_admins" {
  display_name      = "Platform-Admins"
  description       = "Platform team administrators with full access"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "security_team" {
  display_name      = "Security-Team"
  description       = "Security team members"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "engineering_leads" {
  display_name      = "Engineering-Leads"
  description       = "Engineering team leads"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "engineering_developers" {
  display_name      = "Engineering-Developers"
  description       = "Engineering developers"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "data_science_team" {
  display_name      = "DataScience-Team"
  description       = "Data science team members"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "finance_team" {
  display_name      = "Finance-Team"
  description       = "Finance team for billing access"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "auditors" {
  display_name      = "Auditors"
  description       = "External and internal auditors"
  identity_store_id = local.identity_store_id
}
