# -----------------------------------------------------------------------------
# IAM Identity Center Module - Outputs
# -----------------------------------------------------------------------------

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = local.identity_store_id
}

# Permission Set ARNs
output "permission_set_arns" {
  description = "Map of permission set names to ARNs"
  value = {
    administrator   = aws_ssoadmin_permission_set.administrator.arn
    power_user      = aws_ssoadmin_permission_set.power_user.arn
    developer       = aws_ssoadmin_permission_set.developer.arn
    readonly        = aws_ssoadmin_permission_set.readonly.arn
    data_scientist  = aws_ssoadmin_permission_set.data_scientist.arn
    security_auditor = aws_ssoadmin_permission_set.security_auditor.arn
    billing         = aws_ssoadmin_permission_set.billing.arn
    network_admin   = aws_ssoadmin_permission_set.network_admin.arn
  }
}

# Group IDs
output "group_ids" {
  description = "Map of group names to IDs"
  value = {
    platform_admins       = aws_identitystore_group.platform_admins.group_id
    security_team         = aws_identitystore_group.security_team.group_id
    engineering_leads     = aws_identitystore_group.engineering_leads.group_id
    engineering_developers = aws_identitystore_group.engineering_developers.group_id
    data_science_team     = aws_identitystore_group.data_science_team.group_id
    finance_team          = aws_identitystore_group.finance_team.group_id
    auditors              = aws_identitystore_group.auditors.group_id
  }
}

output "sso_start_url" {
  description = "SSO Start URL for users to access AWS accounts"
  value       = "https://${tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]}.awsapps.com/start"
}

# Demo Users
output "demo_users" {
  description = "Map of demo user names to their emails (users receive password setup emails)"
  value = {
    for username, user in aws_identitystore_user.demo : username => {
      email        = user.emails[0].value
      display_name = user.display_name
      user_id      = user.user_id
    }
  }
}
