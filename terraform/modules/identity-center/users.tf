# -----------------------------------------------------------------------------
# IAM Identity Center Users
# Demo users created using email aliases (Gmail + alias feature)
# Set create_demo_users = true to enable user creation
# -----------------------------------------------------------------------------

locals {
  # Parse base email into user and domain parts
  email_parts  = var.base_email != "" ? split("@", var.base_email) : ["", ""]
  email_user   = local.email_parts[0]
  email_domain = length(local.email_parts) > 1 ? local.email_parts[1] : ""

  # Demo users configuration - only created when create_demo_users = true
  demo_users = var.create_demo_users && var.base_email != "" ? {
    "admin" = {
      display_name = "Platform Admin"
      given_name   = "Platform"
      family_name  = "Admin"
      email        = "${local.email_user}+sso-admin@${local.email_domain}"
      groups       = ["platform_admins"]
    }
    "security-lead" = {
      display_name = "Security Lead"
      given_name   = "Security"
      family_name  = "Lead"
      email        = "${local.email_user}+sso-security@${local.email_domain}"
      groups       = ["security_team"]
    }
    "eng-lead" = {
      display_name = "Engineering Lead"
      given_name   = "Engineering"
      family_name  = "Lead"
      email        = "${local.email_user}+sso-eng-lead@${local.email_domain}"
      groups       = ["engineering_leads"]
    }
    "developer" = {
      display_name = "Developer"
      given_name   = "Dev"
      family_name  = "User"
      email        = "${local.email_user}+sso-dev@${local.email_domain}"
      groups       = ["engineering_developers"]
    }
    "data-scientist" = {
      display_name = "Data Scientist"
      given_name   = "Data"
      family_name  = "Scientist"
      email        = "${local.email_user}+sso-datascience@${local.email_domain}"
      groups       = ["data_science_team"]
    }
    "auditor" = {
      display_name = "Auditor"
      given_name   = "External"
      family_name  = "Auditor"
      email        = "${local.email_user}+sso-auditor@${local.email_domain}"
      groups       = ["auditors"]
    }
  } : {}
}

# Create demo users
resource "aws_identitystore_user" "demo" {
  for_each = local.demo_users

  identity_store_id = local.identity_store_id

  display_name = each.value.display_name
  user_name    = each.key

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

# Flatten user-group memberships for demo users
locals {
  demo_user_memberships = flatten([
    for user_name, user_config in local.demo_users : [
      for group in user_config.groups : {
        user  = user_name
        group = group
      }
    ]
  ])

  # Map group names to IDs (use group_id not id)
  group_id_map = {
    "platform_admins"        = aws_identitystore_group.platform_admins.group_id
    "security_team"          = aws_identitystore_group.security_team.group_id
    "engineering_leads"      = aws_identitystore_group.engineering_leads.group_id
    "engineering_developers" = aws_identitystore_group.engineering_developers.group_id
    "data_science_team"      = aws_identitystore_group.data_science_team.group_id
    "finance_team"           = aws_identitystore_group.finance_team.group_id
    "auditors"               = aws_identitystore_group.auditors.group_id
  }
}

# Add demo users to their groups
resource "aws_identitystore_group_membership" "demo" {
  for_each = { for m in local.demo_user_memberships : "${m.user}_${m.group}" => m }

  identity_store_id = local.identity_store_id
  group_id          = local.group_id_map[each.value.group]
  member_id         = aws_identitystore_user.demo[each.value.user].user_id
}
