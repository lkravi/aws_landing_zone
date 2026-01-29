# -----------------------------------------------------------------------------
# AWS Organizations Module - Outputs
# -----------------------------------------------------------------------------

output "organization_id" {
  description = "The ID of the organization"
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "The ARN of the organization"
  value       = aws_organizations_organization.this.arn
}

output "organization_root_id" {
  description = "The ID of the organization root"
  value       = aws_organizations_organization.this.roots[0].id
}

output "management_account_id" {
  description = "The ID of the management account"
  value       = aws_organizations_organization.this.master_account_id
}

# OU IDs
output "ou_ids" {
  description = "Map of OU names to their IDs"
  value = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    workloads      = aws_organizations_organizational_unit.workloads.id
    production     = aws_organizations_organizational_unit.production.id
    non_production = aws_organizations_organizational_unit.non_production.id
    experimental   = aws_organizations_organizational_unit.experimental.id
    suspended      = aws_organizations_organizational_unit.suspended.id
  }
}

output "ou_arns" {
  description = "Map of OU names to their ARNs"
  value = {
    security       = aws_organizations_organizational_unit.security.arn
    infrastructure = aws_organizations_organizational_unit.infrastructure.arn
    workloads      = aws_organizations_organizational_unit.workloads.arn
    production     = aws_organizations_organizational_unit.production.arn
    non_production = aws_organizations_organizational_unit.non_production.arn
    experimental   = aws_organizations_organizational_unit.experimental.arn
    suspended      = aws_organizations_organizational_unit.suspended.arn
  }
}

# Account IDs (only if accounts are created)
output "account_ids" {
  description = "Map of account names to their IDs"
  value = var.create_accounts ? {
    security_tooling    = try(aws_organizations_account.security_tooling[0].id, null)
    log_archive         = try(aws_organizations_account.log_archive[0].id, null)
    network_hub         = try(aws_organizations_account.network_hub[0].id, null)
    shared_services     = try(aws_organizations_account.shared_services[0].id, null)
    prod_engineering    = try(aws_organizations_account.prod_engineering[0].id, null)
    prod_data           = try(aws_organizations_account.prod_data[0].id, null)
    dev_engineering     = try(aws_organizations_account.dev_engineering[0].id, null)
    staging_engineering = try(aws_organizations_account.staging_engineering[0].id, null)
    sandbox_engineering = try(aws_organizations_account.sandbox_engineering[0].id, null)
  } : {}
}

output "all_account_ids" {
  description = "List of all member account IDs for use in policies"
  value = var.create_accounts ? [
    try(aws_organizations_account.security_tooling[0].id, null),
    try(aws_organizations_account.log_archive[0].id, null),
    try(aws_organizations_account.network_hub[0].id, null),
    try(aws_organizations_account.shared_services[0].id, null),
    try(aws_organizations_account.prod_engineering[0].id, null),
    try(aws_organizations_account.prod_data[0].id, null),
    try(aws_organizations_account.dev_engineering[0].id, null),
    try(aws_organizations_account.staging_engineering[0].id, null),
    try(aws_organizations_account.sandbox_engineering[0].id, null),
  ] : []
}
