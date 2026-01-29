# -----------------------------------------------------------------------------
# IAM Identity Center Account Assignments
# Assigns groups to accounts with specific permission sets
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Platform Admins - Full access to all accounts
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "platform_admins_management" {
  count = var.assign_to_accounts ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_group.platform_admins.group_id
  principal_type = "GROUP"

  target_id   = var.management_account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admins_security" {
  for_each = var.assign_to_accounts ? var.security_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_group.platform_admins.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admins_infrastructure" {
  for_each = var.assign_to_accounts ? var.infrastructure_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_group.platform_admins.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admins_workloads" {
  for_each = var.assign_to_accounts ? var.workload_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_group.platform_admins.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

# -----------------------------------------------------------------------------
# Security Team - Security audit on all, Admin on security accounts
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "security_team_audit_all" {
  for_each = var.assign_to_accounts ? merge(
    var.security_account_ids,
    var.infrastructure_account_ids,
    var.workload_account_ids
  ) : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor.arn

  principal_id   = aws_identitystore_group.security_team.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "security_team_admin_security" {
  for_each = var.assign_to_accounts ? var.security_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn

  principal_id   = aws_identitystore_group.security_team.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

# -----------------------------------------------------------------------------
# Engineering Leads - Power user on non-prod, readonly on prod
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "eng_leads_power_nonprod" {
  for_each = var.assign_to_accounts ? var.nonprod_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn

  principal_id   = aws_identitystore_group.engineering_leads.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "eng_leads_readonly_prod" {
  for_each = var.assign_to_accounts ? var.prod_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = aws_identitystore_group.engineering_leads.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

# -----------------------------------------------------------------------------
# Engineering Developers - Developer access on dev and sandbox
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "eng_devs_developer" {
  for_each = var.assign_to_accounts ? merge(
    var.dev_account_ids,
    var.sandbox_account_ids
  ) : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  principal_id   = aws_identitystore_group.engineering_developers.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

# -----------------------------------------------------------------------------
# Data Science Team - Data scientist access on data accounts
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "data_science_access" {
  for_each = var.assign_to_accounts ? var.data_account_ids : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.data_scientist.arn

  principal_id   = aws_identitystore_group.data_science_team.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

# -----------------------------------------------------------------------------
# Finance Team - Billing on management, readonly on all
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "finance_billing" {
  count = var.assign_to_accounts ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.billing.arn

  principal_id   = aws_identitystore_group.finance_team.group_id
  principal_type = "GROUP"

  target_id   = var.management_account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "finance_readonly_all" {
  for_each = var.assign_to_accounts ? merge(
    var.security_account_ids,
    var.infrastructure_account_ids,
    var.workload_account_ids
  ) : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = aws_identitystore_group.finance_team.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

# -----------------------------------------------------------------------------
# Auditors - Readonly on all accounts
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "auditors_readonly" {
  for_each = var.assign_to_accounts ? merge(
    { management = var.management_account_id },
    var.security_account_ids,
    var.infrastructure_account_ids,
    var.workload_account_ids
  ) : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = aws_identitystore_group.auditors.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}
