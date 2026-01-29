# -----------------------------------------------------------------------------
# AWS Organizations Module - Variables
# -----------------------------------------------------------------------------

variable "organization_name" {
  description = "Name of the organization (used in resource naming)"
  type        = string
}

variable "create_accounts" {
  description = "Whether to create member accounts. Set to false for initial planning."
  type        = bool
  default     = false
}

variable "organization_access_role" {
  description = "Name of the IAM role for cross-account access from management account"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "account_emails" {
  description = "Email addresses for member accounts (each account needs unique email)"
  type        = map(string)
  default     = {}

  # Example:
  # {
  #   security_tooling    = "aws-security@techcorp.com"
  #   log_archive         = "aws-logs@techcorp.com"
  #   network_hub         = "aws-network@techcorp.com"
  #   shared_services     = "aws-shared@techcorp.com"
  #   prod_engineering    = "aws-prod-eng@techcorp.com"
  #   prod_data           = "aws-prod-data@techcorp.com"
  #   dev_engineering     = "aws-dev-eng@techcorp.com"
  #   staging_engineering = "aws-staging-eng@techcorp.com"
  #   sandbox_engineering = "aws-sandbox-eng@techcorp.com"
  # }
}
