# -----------------------------------------------------------------------------
# GuardDuty Organization Module
# Enables GuardDuty across all organization accounts
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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# GuardDuty Detector (Management Account)
# -----------------------------------------------------------------------------

resource "aws_guardduty_detector" "primary" {
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = var.enable_kubernetes_audit_logs
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-guardduty-detector"
    Purpose = "Threat detection"
  })
}

# -----------------------------------------------------------------------------
# GuardDuty Organization Configuration
# Delegates administration to Security Tooling account (if specified)
# -----------------------------------------------------------------------------

resource "aws_guardduty_organization_admin_account" "delegated_admin" {
  count = var.enable_delegated_admin ? 1 : 0

  admin_account_id = var.delegated_admin_account_id

  depends_on = [aws_guardduty_detector.primary]
}

# -----------------------------------------------------------------------------
# GuardDuty Organization Configuration
# Auto-enable for new accounts
# -----------------------------------------------------------------------------

resource "aws_guardduty_organization_configuration" "this" {
  count = var.is_delegated_admin ? 1 : 0

  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.primary.id

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        enable = var.enable_kubernetes_audit_logs
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = var.enable_malware_protection
        }
      }
    }
  }

  depends_on = [aws_guardduty_detector.primary]
}

# -----------------------------------------------------------------------------
# GuardDuty Publishing Destination (Optional - for S3 export)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "guardduty_findings" {
  count = var.create_findings_bucket ? 1 : 0

  bucket        = "${var.name_prefix}-guardduty-findings-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-guardduty-findings"
    Purpose = "GuardDuty findings export"
  })
}

resource "aws_s3_bucket_versioning" "guardduty_findings" {
  count = var.create_findings_bucket ? 1 : 0

  bucket = aws_s3_bucket.guardduty_findings[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty_findings" {
  count = var.create_findings_bucket ? 1 : 0

  bucket = aws_s3_bucket.guardduty_findings[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.guardduty[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "guardduty_findings" {
  count = var.create_findings_bucket ? 1 : 0

  bucket = aws_s3_bucket.guardduty_findings[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "guardduty" {
  count = var.create_findings_bucket ? 1 : 0

  description             = "KMS key for GuardDuty findings encryption"
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
        Sid    = "Allow GuardDuty to encrypt findings"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "kms:GenerateDataKey"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-guardduty-key"
    Purpose = "GuardDuty findings encryption"
  })
}

resource "aws_s3_bucket_policy" "guardduty_findings" {
  count = var.create_findings_bucket ? 1 : 0

  bucket = aws_s3_bucket.guardduty_findings[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGuardDutyGetBucketLocation"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:GetBucketLocation"
        Resource = aws_s3_bucket.guardduty_findings[0].arn
      },
      {
        Sid    = "AllowGuardDutyPutObject"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.guardduty_findings[0].arn}/*"
      }
    ]
  })
}

resource "aws_guardduty_publishing_destination" "s3" {
  count = var.create_findings_bucket ? 1 : 0

  detector_id     = aws_guardduty_detector.primary.id
  destination_arn = aws_s3_bucket.guardduty_findings[0].arn
  kms_key_arn     = aws_kms_key.guardduty[0].arn

  depends_on = [aws_s3_bucket_policy.guardduty_findings]
}

# -----------------------------------------------------------------------------
# SNS Topic for GuardDuty Alerts (Optional)
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "guardduty_alerts" {
  count = var.create_sns_topic ? 1 : 0

  name = "${var.name_prefix}-guardduty-alerts"

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-guardduty-alerts"
    Purpose = "GuardDuty alert notifications"
  })
}

resource "aws_sns_topic_policy" "guardduty_alerts" {
  count = var.create_sns_topic ? 1 : 0

  arn = aws_sns_topic.guardduty_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.guardduty_alerts[0].arn
      }
    ]
  })
}

# EventBridge Rule for high severity findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.create_sns_topic ? 1 : 0

  name        = "${var.name_prefix}-guardduty-high-severity"
  description = "Capture high severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-guardduty-high-severity"
    Purpose = "Alert on high severity findings"
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  count = var.create_sns_topic ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "guardduty-to-sns"
  arn       = aws_sns_topic.guardduty_alerts[0].arn
}
