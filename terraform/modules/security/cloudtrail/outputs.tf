# -----------------------------------------------------------------------------
# CloudTrail Module - Outputs
# -----------------------------------------------------------------------------

output "trail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.organization.name
}

output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.organization.arn
}

output "trail_id" {
  description = "ID of the CloudTrail trail"
  value       = aws_cloudtrail.organization.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key for CloudTrail encryption"
  value       = aws_kms_key.cloudtrail.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for CloudTrail"
  value       = try(aws_cloudwatch_log_group.cloudtrail[0].name, null)
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for CloudTrail"
  value       = try(aws_cloudwatch_log_group.cloudtrail[0].arn, null)
}
