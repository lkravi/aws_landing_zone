# -----------------------------------------------------------------------------
# Service Control Policies (SCPs)
# These policies enforce guardrails across the organization
# Policies are defined inline for module portability
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SCP Policy Documents (Inline)
# -----------------------------------------------------------------------------

locals {
  scp_deny_root_user = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootUserActions"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })

  scp_deny_leave_organization = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeaveOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }
    ]
  })

  scp_require_imdsv2 = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RequireImdsV2"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:MetadataHttpTokens" = "required"
          }
        }
      }
    ]
  })

  scp_deny_region_restriction = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllOutsideAllowedRegions"
        Effect = "Deny"
        NotAction = [
          "a4b:*",
          "acm:*",
          "aws-marketplace-management:*",
          "aws-marketplace:*",
          "aws-portal:*",
          "budgets:*",
          "ce:*",
          "chime:*",
          "cloudfront:*",
          "config:*",
          "cur:*",
          "directconnect:*",
          "ec2:DescribeRegions",
          "ec2:DescribeTransitGateways",
          "ec2:DescribeVpnGateways",
          "fms:*",
          "globalaccelerator:*",
          "health:*",
          "iam:*",
          "importexport:*",
          "kms:*",
          "mobileanalytics:*",
          "networkmanager:*",
          "organizations:*",
          "pricing:*",
          "route53:*",
          "route53domains:*",
          "route53-recovery-cluster:*",
          "route53-recovery-control-config:*",
          "route53-recovery-readiness:*",
          "s3:GetAccountPublic*",
          "s3:ListAllMyBuckets",
          "s3:ListMultiRegionAccessPoints",
          "s3:PutAccountPublic*",
          "shield:*",
          "sts:*",
          "support:*",
          "trustedadvisor:*",
          "waf-regional:*",
          "waf:*",
          "wafv2:*",
          "wellarchitected:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = ["ap-southeast-2", "ap-southeast-4"]
          }
        }
      }
    ]
  })

  scp_protect_security_services = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisablingCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors"
        ]
        Resource = "arn:aws:cloudtrail:*:*:trail/organization-*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
              "arn:aws:iam::*:role/AWSControlTowerExecution"
            ]
          }
        }
      },
      {
        Sid    = "DenyDisablingGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DeleteMembers",
          "guardduty:DisassociateMembers",
          "guardduty:StopMonitoringMembers",
          "guardduty:UpdateDetector"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
              "arn:aws:iam::*:role/AWSControlTowerExecution"
            ]
          }
        }
      },
      {
        Sid    = "DenyDisablingSecurityHub"
        Effect = "Deny"
        Action = [
          "securityhub:DisableSecurityHub",
          "securityhub:DeleteMembers",
          "securityhub:DisassociateMembers"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
              "arn:aws:iam::*:role/AWSControlTowerExecution"
            ]
          }
        }
      },
      {
        Sid    = "DenyDisablingConfig"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
              "arn:aws:iam::*:role/AWSControlTowerExecution"
            ]
          }
        }
      }
    ]
  })

  scp_deny_public_s3 = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3BucketACL"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:DeletePublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = ["arn:aws:iam::*:role/OrganizationAccountAccessRole"]
          }
        }
      },
      {
        Sid      = "DenyPublicObjectACL"
        Effect   = "Deny"
        Action   = "s3:PutObjectAcl"
        Resource = "*"
        Condition = {
          StringEqualsIgnoreCase = {
            "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"]
          }
        }
      }
    ]
  })

  scp_sandbox_restrictions = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyExpensiveEC2Instances"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          "ForAnyValue:StringLike" = {
            "ec2:InstanceType" = [
              "*.metal",
              "*.8xlarge",
              "*.10xlarge",
              "*.12xlarge",
              "*.16xlarge",
              "*.18xlarge",
              "*.24xlarge",
              "p2.*",
              "p3.*",
              "p4*",
              "g3.*",
              "g4*",
              "g5*",
              "inf1.*",
              "dl1.*",
              "trn1.*"
            ]
          }
        }
      },
      {
        Sid      = "DenyExpensiveRDSInstances"
        Effect   = "Deny"
        Action   = ["rds:CreateDBInstance", "rds:ModifyDBInstance"]
        Resource = "*"
        Condition = {
          "ForAnyValue:StringLike" = {
            "rds:DatabaseClass" = [
              "db.*.8xlarge",
              "db.*.12xlarge",
              "db.*.16xlarge",
              "db.*.24xlarge"
            ]
          }
        }
      },
      {
        Sid      = "DenyOrganizationAccess"
        Effect   = "Deny"
        Action   = ["organizations:*", "account:*"]
        Resource = "*"
      },
      {
        Sid      = "DenyIAMUserCreation"
        Effect   = "Deny"
        Action   = ["iam:CreateUser", "iam:CreateAccessKey"]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Baseline SCPs - Applied to all accounts
# -----------------------------------------------------------------------------

resource "aws_organizations_policy" "deny_root_user" {
  name        = "DenyRootUserActions"
  description = "Deny all actions by the root user"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_deny_root_user

  tags = {
    Purpose   = "Security baseline"
    ManagedBy = "terraform"
  }
}

resource "aws_organizations_policy" "deny_leave_organization" {
  name        = "DenyLeaveOrganization"
  description = "Prevent accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_deny_leave_organization

  tags = {
    Purpose   = "Governance"
    ManagedBy = "terraform"
  }
}

resource "aws_organizations_policy" "require_imdsv2" {
  name        = "RequireIMDSv2"
  description = "Require Instance Metadata Service Version 2 for EC2 instances"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_require_imdsv2

  tags = {
    Purpose   = "Security baseline"
    ManagedBy = "terraform"
  }
}

resource "aws_organizations_policy" "deny_region_restriction" {
  name        = "DenyRegionRestriction"
  description = "Restrict deployments to allowed regions only (ap-southeast-2, ap-southeast-4)"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_deny_region_restriction

  tags = {
    Purpose   = "Compliance"
    ManagedBy = "terraform"
  }
}

resource "aws_organizations_policy" "protect_security_services" {
  name        = "ProtectSecurityServices"
  description = "Prevent modification of security services (CloudTrail, GuardDuty, Config, Security Hub)"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_protect_security_services

  tags = {
    Purpose   = "Security baseline"
    ManagedBy = "terraform"
  }
}

resource "aws_organizations_policy" "deny_public_s3" {
  name        = "DenyPublicS3Buckets"
  description = "Prevent creation of public S3 buckets"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_deny_public_s3

  tags = {
    Purpose   = "Security baseline"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Environment-Specific SCPs
# -----------------------------------------------------------------------------

resource "aws_organizations_policy" "sandbox_restrictions" {
  name        = "SandboxRestrictions"
  description = "Additional restrictions for sandbox/experimental accounts"
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.scp_sandbox_restrictions

  tags = {
    Purpose   = "Cost control"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# SCP Attachments - Root Level (applies to all accounts except management)
# -----------------------------------------------------------------------------

resource "aws_organizations_policy_attachment" "deny_leave_organization_root" {
  policy_id = aws_organizations_policy.deny_leave_organization.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "deny_region_restriction_root" {
  policy_id = aws_organizations_policy.deny_region_restriction.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "require_imdsv2_root" {
  policy_id = aws_organizations_policy.require_imdsv2.id
  target_id = aws_organizations_organization.this.roots[0].id
}

# -----------------------------------------------------------------------------
# SCP Attachments - Security OU
# -----------------------------------------------------------------------------

resource "aws_organizations_policy_attachment" "protect_security_services_security_ou" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.security.id
}

# -----------------------------------------------------------------------------
# SCP Attachments - Workloads OU (Production, Non-Production)
# -----------------------------------------------------------------------------

resource "aws_organizations_policy_attachment" "deny_root_user_workloads" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_public_s3_workloads" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "protect_security_services_workloads" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# -----------------------------------------------------------------------------
# SCP Attachments - Experimental OU (Sandbox accounts)
# -----------------------------------------------------------------------------

resource "aws_organizations_policy_attachment" "sandbox_restrictions_experimental" {
  policy_id = aws_organizations_policy.sandbox_restrictions.id
  target_id = aws_organizations_organizational_unit.experimental.id
}

# -----------------------------------------------------------------------------
# SCP Outputs
# -----------------------------------------------------------------------------

output "scp_ids" {
  description = "Map of SCP names to their IDs"
  value = {
    deny_root_user            = aws_organizations_policy.deny_root_user.id
    deny_leave_organization   = aws_organizations_policy.deny_leave_organization.id
    require_imdsv2            = aws_organizations_policy.require_imdsv2.id
    deny_region_restriction   = aws_organizations_policy.deny_region_restriction.id
    protect_security_services = aws_organizations_policy.protect_security_services.id
    deny_public_s3            = aws_organizations_policy.deny_public_s3.id
    sandbox_restrictions      = aws_organizations_policy.sandbox_restrictions.id
  }
}
