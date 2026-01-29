# -----------------------------------------------------------------------------
# IAM Identity Center Module - Variables
# -----------------------------------------------------------------------------

variable "assign_to_accounts" {
  description = "Whether to assign groups to accounts. Set to false for initial setup."
  type        = bool
  default     = false
}

variable "management_account_id" {
  description = "Management account ID"
  type        = string
  default     = ""
}

variable "security_account_ids" {
  description = "Map of security account names to IDs"
  type        = map(string)
  default     = {}
}

variable "infrastructure_account_ids" {
  description = "Map of infrastructure account names to IDs"
  type        = map(string)
  default     = {}
}

variable "workload_account_ids" {
  description = "Map of all workload account names to IDs"
  type        = map(string)
  default     = {}
}

variable "prod_account_ids" {
  description = "Map of production account names to IDs"
  type        = map(string)
  default     = {}
}

variable "nonprod_account_ids" {
  description = "Map of non-production account names to IDs (dev + staging)"
  type        = map(string)
  default     = {}
}

variable "dev_account_ids" {
  description = "Map of development account names to IDs"
  type        = map(string)
  default     = {}
}

variable "sandbox_account_ids" {
  description = "Map of sandbox account names to IDs"
  type        = map(string)
  default     = {}
}

variable "data_account_ids" {
  description = "Map of data/ML account names to IDs"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# User Configuration
# -----------------------------------------------------------------------------

variable "create_demo_users" {
  description = "Whether to create demo users. Set to true after initial setup to create SSO users."
  type        = bool
  default     = false
}

variable "base_email" {
  description = "Base email for generating user emails with aliases (e.g., user@gmail.com becomes user+sso-admin@gmail.com)"
  type        = string
  default     = ""
}
