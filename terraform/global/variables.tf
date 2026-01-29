# -----------------------------------------------------------------------------
# Global Variables - Used across all environments
# -----------------------------------------------------------------------------

variable "organization_name" {
  description = "Name of the organization (used in resource naming)"
  type        = string
  default     = "techcorp"
}

variable "primary_region" {
  description = "Primary AWS region for deployments"
  type        = string
  default     = "ap-southeast-2" # Sydney
}

variable "secondary_region" {
  description = "Secondary AWS region for DR/backup"
  type        = string
  default     = "ap-southeast-4" # Melbourne
}

variable "allowed_regions" {
  description = "List of AWS regions allowed for resource deployment"
  type        = list(string)
  default     = ["ap-southeast-2", "ap-southeast-4"]
}

variable "environments" {
  description = "Map of environment configurations"
  type = map(object({
    short_name  = string
    description = string
    is_prod     = bool
  }))
  default = {
    prod = {
      short_name  = "prd"
      description = "Production environment"
      is_prod     = true
    }
    staging = {
      short_name  = "stg"
      description = "Staging environment"
      is_prod     = false
    }
    dev = {
      short_name  = "dev"
      description = "Development environment"
      is_prod     = false
    }
    sandbox = {
      short_name  = "sbx"
      description = "Sandbox/Experimental environment"
      is_prod     = false
    }
  }
}

variable "departments" {
  description = "List of departments in the organization"
  type = map(object({
    name        = string
    cost_center = string
    owner_email = string
  }))
  default = {
    engineering = {
      name        = "Engineering"
      cost_center = "CC-1001"
      owner_email = "engineering@techcorp.com"
    }
    data-science = {
      name        = "Data Science"
      cost_center = "CC-1002"
      owner_email = "datascience@techcorp.com"
    }
    platform = {
      name        = "Platform"
      cost_center = "CC-1003"
      owner_email = "platform@techcorp.com"
    }
  }
}

# Tagging Configuration
variable "mandatory_tags" {
  description = "Tags that must be present on all resources"
  type        = list(string)
  default     = ["Environment", "Department", "Project", "CostCenter", "Owner", "ManagedBy"]
}
