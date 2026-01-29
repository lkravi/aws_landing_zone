# -----------------------------------------------------------------------------
# GuardDuty Module - Outputs
# -----------------------------------------------------------------------------

output "detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.primary.id
}

output "detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = aws_guardduty_detector.primary.arn
}

output "findings_bucket_name" {
  description = "Name of the S3 bucket for GuardDuty findings"
  value       = try(aws_s3_bucket.guardduty_findings[0].id, null)
}

output "findings_bucket_arn" {
  description = "ARN of the S3 bucket for GuardDuty findings"
  value       = try(aws_s3_bucket.guardduty_findings[0].arn, null)
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for GuardDuty alerts"
  value       = try(aws_sns_topic.guardduty_alerts[0].arn, null)
}

output "kms_key_arn" {
  description = "ARN of the KMS key for GuardDuty findings encryption"
  value       = try(aws_kms_key.guardduty[0].arn, null)
}
