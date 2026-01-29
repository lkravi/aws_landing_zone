# Operational Runbooks

This document contains standard operating procedures for Day 2 operations.

## Table of Contents

1. [Account Vending - Creating New Accounts](#1-account-vending---creating-new-accounts)
2. [User Onboarding](#2-user-onboarding)
3. [User Offboarding](#3-user-offboarding)
4. [Security Incident Response](#4-security-incident-response)
5. [Cost Anomaly Investigation](#5-cost-anomaly-investigation)
6. [Environment Cleanup](#6-environment-cleanup)
7. [Disaster Recovery](#7-disaster-recovery)

---

## 1. Account Vending - Creating New Accounts

### When to Use
- New project requires isolated AWS environment
- New department joining the organization
- Sandbox request for experimentation

### Prerequisites
- Unique email address for the new account
- Approved budget allocation
- Defined OU placement

### Procedure

#### Step 1: Add Account Configuration

Edit `terraform/modules/organization/main.tf`:

```hcl
resource "aws_organizations_account" "new_account_name" {
  count = var.create_accounts ? 1 : 0

  name      = "${var.organization_name}-<env>-<dept>-<purpose>"
  email     = var.account_emails["new_account_name"]
  parent_id = aws_organizations_organizational_unit.<appropriate_ou>.id

  iam_user_access_to_billing = "DENY"
  role_name                  = var.organization_access_role

  tags = {
    Environment = "<environment>"
    Department  = "<department>"
    Purpose     = "<purpose>"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}
```

#### Step 2: Add Email to Variables

Edit `terraform/environments/management/main.tf`:

```hcl
variable "account_emails" {
  default = {
    # ... existing accounts ...
    new_account_name = "aws+newaccount@domain.com"
  }
}
```

#### Step 3: Apply Changes

```bash
cd terraform/environments/management
terraform plan -var="aws_profile=techcorp-admin"
terraform apply -var="aws_profile=techcorp-admin"
```

#### Step 4: Assign IAM Identity Center Access

Add appropriate group assignments in `terraform/modules/identity-center/assignments.tf`.

#### Step 5: Deploy Account Baseline

1. Create VPC
2. Enable security services
3. Configure logging

### Post-Procedure Verification

- [ ] Account appears in AWS Organizations console
- [ ] Account is in correct OU
- [ ] SCPs are applied
- [ ] IAM Identity Center access works
- [ ] Security services are enabled

---

## 2. User Onboarding

### When to Use
- New employee joining
- Contractor requiring access
- Cross-team access request

### Prerequisites
- Approved access request
- User's email address
- Manager approval

### Procedure

#### Step 2.1: Create User in IAM Identity Center

**Via Console:**
1. Go to IAM Identity Center > Users
2. Click "Add user"
3. Fill in:
   - Username: firstname.lastname
   - Email: user@company.com
   - First name, Last name
4. Click "Next"
5. Add to appropriate groups
6. Click "Add user"

**Via AWS CLI:**
```bash
# Get Identity Store ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances \
  --query 'Instances[0].IdentityStoreId' \
  --output text \
  --profile techcorp-admin)

# Create user
aws identitystore create-user \
  --identity-store-id $IDENTITY_STORE_ID \
  --user-name "john.doe" \
  --display-name "John Doe" \
  --name '{"FamilyName":"Doe","GivenName":"John"}' \
  --emails '[{"Value":"john.doe@company.com","Primary":true}]' \
  --profile techcorp-admin
```

#### Step 2.2: Add User to Groups

```bash
# Get user ID
USER_ID=$(aws identitystore list-users \
  --identity-store-id $IDENTITY_STORE_ID \
  --filters '[{"AttributePath":"UserName","AttributeValue":"john.doe"}]' \
  --query 'Users[0].UserId' \
  --output text \
  --profile techcorp-admin)

# Get group ID
GROUP_ID=$(aws identitystore list-groups \
  --identity-store-id $IDENTITY_STORE_ID \
  --filters '[{"AttributePath":"DisplayName","AttributeValue":"Engineering-Developers"}]' \
  --query 'Groups[0].GroupId' \
  --output text \
  --profile techcorp-admin)

# Add to group
aws identitystore create-group-membership \
  --identity-store-id $IDENTITY_STORE_ID \
  --group-id $GROUP_ID \
  --member-id '{"UserId":"'$USER_ID'"}' \
  --profile techcorp-admin
```

#### Step 2.3: Send Welcome Email

Send the user:
- SSO Start URL: `https://d-xxxxxxxxxx.awsapps.com/start`
- Instructions for first-time login
- Link to this runbook

### Post-Procedure Verification

- [ ] User can log in to SSO portal
- [ ] User sees correct accounts
- [ ] User can assume roles successfully

---

## 3. User Offboarding

### When to Use
- Employee leaving
- Contractor engagement ending
- Access revocation (security)

### Prerequisites
- Offboarding approval
- List of user's access

### Procedure

#### Step 3.1: Remove from All Groups

```bash
# List user's group memberships
aws identitystore list-group-memberships-for-member \
  --identity-store-id $IDENTITY_STORE_ID \
  --member-id '{"UserId":"'$USER_ID'"}' \
  --profile techcorp-admin

# Remove from each group
aws identitystore delete-group-membership \
  --identity-store-id $IDENTITY_STORE_ID \
  --membership-id <membership-id> \
  --profile techcorp-admin
```

#### Step 3.2: Disable User

```bash
# Disable (don't delete immediately for audit purposes)
# Note: AWS IAM Identity Center doesn't have direct disable API
# Delete the user to revoke access
aws identitystore delete-user \
  --identity-store-id $IDENTITY_STORE_ID \
  --user-id $USER_ID \
  --profile techcorp-admin
```

#### Step 3.3: Review for Orphaned Resources

Check for:
- Personal IAM users (shouldn't exist)
- Access keys
- API credentials in Secrets Manager
- Resources tagged with user's name

### Post-Procedure Verification

- [ ] User cannot log in
- [ ] User's sessions are terminated
- [ ] No orphaned resources remain
- [ ] Audit trail is complete

---

## 4. Security Incident Response

### When to Use
- GuardDuty finding (High/Critical severity)
- Suspicious activity reported
- Potential compromise

### Severity Levels

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| Critical (8-10) | 15 minutes | Immediate - Security Lead |
| High (7-8) | 1 hour | Security Team |
| Medium (4-7) | 24 hours | Ticket + Review |
| Low (1-4) | 7 days | Scheduled Review |

### Procedure

#### Step 4.1: Assess the Finding

```bash
# Get GuardDuty findings
aws guardduty list-findings \
  --detector-id <detector-id> \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}' \
  --profile techcorp-admin

# Get finding details
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id> \
  --profile techcorp-admin
```

#### Step 4.2: Contain (if needed)

**Isolate EC2 Instance:**
```bash
# Create isolation security group (no inbound/outbound)
aws ec2 create-security-group \
  --group-name "isolation-sg" \
  --description "Isolation security group for incident response" \
  --vpc-id <vpc-id> \
  --profile techcorp-admin

# Attach to instance (removes all other SGs)
aws ec2 modify-instance-attribute \
  --instance-id <instance-id> \
  --groups <isolation-sg-id> \
  --profile techcorp-admin
```

**Disable IAM User:**
```bash
# Deactivate all access keys
aws iam list-access-keys --user-name <username> --profile techcorp-admin
aws iam update-access-key \
  --user-name <username> \
  --access-key-id <key-id> \
  --status Inactive \
  --profile techcorp-admin
```

#### Step 4.3: Investigate

1. Review CloudTrail logs
2. Check VPC Flow Logs
3. Analyze GuardDuty finding details
4. Review resource configuration history (AWS Config)

```bash
# Search CloudTrail for user activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<username> \
  --start-time 2024-01-01T00:00:00Z \
  --profile techcorp-admin
```

#### Step 4.4: Remediate

Based on finding type:
- Rotate compromised credentials
- Patch vulnerable systems
- Update security groups
- Enable additional logging

#### Step 4.5: Document

Create incident report with:
- Timeline of events
- Actions taken
- Root cause
- Lessons learned
- Prevention measures

---

## 5. Cost Anomaly Investigation

### When to Use
- Budget alert triggered
- Unexpected cost spike
- Monthly cost review

### Procedure

#### Step 5.1: Identify Cost Driver

```bash
# Get cost by service
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --profile techcorp-admin
```

#### Step 5.2: Analyze by Tag

```bash
# Get cost by cost center
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=TAG,Key=CostCenter \
  --profile techcorp-admin
```

#### Step 5.3: Find Untagged Resources

```bash
# List untagged EC2 instances
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[?!Tags].InstanceId' \
  --profile techcorp-admin
```

#### Step 5.4: Remediation Actions

Common cost reduction actions:
- Terminate unused resources
- Right-size over-provisioned instances
- Enable auto-scaling
- Switch to Reserved Instances/Savings Plans
- Implement scheduled shutdowns for dev

---

## 6. Environment Cleanup

### When to Use
- Project completed
- Learning environment no longer needed
- Cost optimization

### Full Cleanup Procedure

#### Step 6.1: Document Current State

```bash
# Export organization structure
aws organizations describe-organization --profile techcorp-admin > org-backup.json

# List all accounts
aws organizations list-accounts --profile techcorp-admin > accounts-backup.json
```

#### Step 6.2: Clean Member Account Resources

For each member account:

```bash
# Assume role into account
# Then delete resources in order:
# 1. EC2 instances
# 2. RDS databases
# 3. ELBs
# 4. NAT Gateways
# 5. VPCs
# 6. S3 buckets (empty first)
```

#### Step 6.3: Destroy Terraform Resources

```bash
# Destroy in reverse order of creation
cd terraform/environments/management
terraform destroy -var="aws_profile=techcorp-admin" -var="create_accounts=false"

# Note: This won't delete member accounts!
```

#### Step 6.4: Close Member Accounts

**Cannot be automated - manual process:**

1. Go to AWS Organizations console
2. Select each member account
3. Click "Remove" to move to standalone
4. Sign in to each account as root
5. Go to Account Settings
6. Click "Close Account"

> **Warning**: Accounts take 90 days to fully close. You'll still see them during this period.

#### Step 6.5: Delete Bootstrap Resources

```bash
cd terraform/environments/bootstrap

# Empty the S3 bucket first
aws s3 rm s3://techcorp-terraform-state-ap-southeast-2 --recursive --profile techcorp-admin

terraform destroy -var="aws_profile=techcorp-admin"
```

#### Step 6.6: Delete IAM User

1. Go to IAM console
2. Delete the terraform-setup user
3. Remove any remaining access keys

---

## 7. Disaster Recovery

### When to Use
- Primary region failure
- Data corruption
- Major service outage

### Procedure

#### Step 7.1: Assess Impact

Determine:
- Which services are affected
- Which regions are impacted
- RPO/RTO requirements

#### Step 7.2: Activate DR Region

If using multi-region setup:

```bash
# Update DNS to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dr-dns-change.json \
  --profile techcorp-admin
```

#### Step 7.3: Restore from Backups

```bash
# Restore S3 objects from Glacier
aws s3api restore-object \
  --bucket <bucket> \
  --key <key> \
  --restore-request '{"Days":7}' \
  --profile techcorp-admin

# Restore RDS from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <new-instance-name> \
  --db-snapshot-identifier <snapshot-id> \
  --profile techcorp-admin
```

#### Step 7.4: Validate Recovery

- [ ] All critical services accessible
- [ ] Data integrity verified
- [ ] User access working
- [ ] Monitoring active

#### Step 7.5: Document Incident

Create post-incident report including:
- Timeline
- Actions taken
- Data loss (if any)
- Improvement recommendations

---

## Quick Reference Commands

### Organization
```bash
# List accounts
aws organizations list-accounts --profile techcorp-admin

# List OUs
aws organizations list-organizational-units-for-parent --parent-id <id> --profile techcorp-admin
```

### IAM Identity Center
```bash
# List users
aws identitystore list-users --identity-store-id <id> --profile techcorp-admin

# List groups
aws identitystore list-groups --identity-store-id <id> --profile techcorp-admin
```

### Security
```bash
# GuardDuty findings
aws guardduty list-findings --detector-id <id> --profile techcorp-admin

# CloudTrail events
aws cloudtrail lookup-events --profile techcorp-admin
```

### Cost
```bash
# Current month cost
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics "UnblendedCost" --profile techcorp-admin
```

---

*Runbooks Version 1.0 - Last Updated: 2024-01-24*
