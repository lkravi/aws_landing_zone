# -----------------------------------------------------------------------------
# GuardDuty Module - Variables
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "finding_publishing_frequency" {
  description = "Frequency of finding publication (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "enable_kubernetes_audit_logs" {
  description = "Enable Kubernetes audit logs monitoring"
  type        = bool
  default     = true
}

variable "enable_malware_protection" {
  description = "Enable malware protection for EBS volumes"
  type        = bool
  default     = true
}

variable "enable_delegated_admin" {
  description = "Whether to enable delegated admin (set to true when security account exists)"
  type        = bool
  default     = false
}

variable "delegated_admin_account_id" {
  description = "Account ID to delegate GuardDuty administration to (leave empty for management account)"
  type        = string
  default     = ""
}

variable "is_delegated_admin" {
  description = "Whether this is running in the delegated admin account"
  type        = bool
  default     = false
}

variable "create_findings_bucket" {
  description = "Whether to create an S3 bucket for findings export"
  type        = bool
  default     = true
}

variable "create_sns_topic" {
  description = "Whether to create SNS topic for alerts"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
