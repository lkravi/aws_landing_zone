# Implementation Guide

This guide walks you through deploying the AWS Enterprise Landing Zone step by step.

## Prerequisites

Before starting, ensure you have:

- [ ] New AWS Account created (will become Management Account)
- [ ] AWS CLI v2 installed
- [ ] Terraform >= 1.5.0 installed
- [ ] Git installed
- [ ] Email addresses ready for member accounts (can use aliases like aws+security@domain.com)

## Phase 1: Initial Setup

### Step 1.1: Create AWS Account

1. Go to [aws.amazon.com](https://aws.amazon.com) and create a new account
2. This account will become your **Management Account**
3. Sign in as root user and enable MFA (Security Credentials > MFA)

### Step 1.2: Create Initial IAM User

Since we'll use IAM Identity Center later, create a temporary IAM user for initial setup:

1. Go to IAM Console
2. Create user: `terraform-setup`
3. Attach policy: `AdministratorAccess`
4. Create access keys (CLI access)
5. Save the Access Key ID and Secret Access Key

### Step 1.3: Configure AWS CLI Profile

```bash
# Navigate to project directory
cd /path/to/aws_devops

# Run the setup script
./scripts/setup-aws-profile.sh techcorp-admin

# Or manually configure
aws configure --profile techcorp-admin
# Enter your Access Key ID
# Enter your Secret Access Key
# Default region: ap-southeast-2
# Output format: json
```

### Step 1.4: Verify Access

```bash
export AWS_PROFILE=techcorp-admin
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-setup"
}
```

## Phase 2: Bootstrap Terraform State

### Step 2.1: Initialize and Apply Bootstrap

```bash
cd terraform/environments/bootstrap

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var="aws_profile=techcorp-admin"

# Apply (creates S3 bucket and DynamoDB table)
terraform apply -var="aws_profile=techcorp-admin"
```

### Step 2.2: Note the Outputs

Save these values for later:
- `state_bucket_name`
- `dynamodb_table_name`

### Step 2.3: Migrate State to S3 (Optional for bootstrap)

After the S3 bucket is created, you can migrate the bootstrap state:

1. Uncomment the `backend "s3"` block in `bootstrap/main.tf`
2. Run `terraform init -migrate-state`

## Phase 3: AWS Organizations Setup

### Step 3.1: Deploy Organization Structure

```bash
cd ../management

# Initialize with local state first
terraform init

# Deploy organization WITHOUT creating member accounts first
terraform plan -var="aws_profile=techcorp-admin" -var="create_accounts=false"
terraform apply -var="aws_profile=techcorp-admin" -var="create_accounts=false"
```

This creates:
- AWS Organization
- Organizational Units (Security, Infrastructure, Workloads, etc.)
- Service Control Policies
- IAM Identity Center groups and permission sets

### Step 3.2: Review Organization in Console

1. Go to AWS Organizations console
2. Verify OU structure is created
3. Check Service Control Policies are attached

### Step 3.3: Enable IAM Identity Center

IAM Identity Center must be enabled manually before Terraform can manage it:

1. Go to IAM Identity Center console
2. Click "Enable"
3. Choose your identity source (built-in for now)
4. Note the SSO Start URL

## Phase 4: Create Member Accounts (Optional)

> **Cost Warning**: Creating member accounts will incur costs. Skip this for learning/demo purposes if budget is a concern.

### Step 4.1: Prepare Email Addresses

Each AWS account needs a unique email. You can use email aliases:
- aws+security@yourdomain.com
- aws+logs@yourdomain.com
- aws+network@yourdomain.com
- etc.

### Step 4.2: Update Account Emails

Edit `terraform/environments/management/main.tf`:

```hcl
variable "account_emails" {
  default = {
    security_tooling    = "your-actual-email+security@domain.com"
    log_archive         = "your-actual-email+logs@domain.com"
    # ... update all emails
  }
}
```

### Step 4.3: Create Accounts

```bash
# This will create all member accounts - CANNOT BE UNDONE via Terraform!
terraform apply -var="aws_profile=techcorp-admin" -var="create_accounts=true"
```

> **Important**: AWS accounts cannot be deleted via Terraform. You must close them manually in the AWS console.

## Phase 5: IAM Identity Center Users

### Step 5.1: Create Users in Console

1. Go to IAM Identity Center > Users
2. Create users for testing:
   - `platform-admin@techcorp.com`
   - `developer@techcorp.com`
   - `auditor@techcorp.com`

### Step 5.2: Add Users to Groups

1. Go to Groups
2. Add users to appropriate groups:
   - `Platform-Admins`: platform-admin
   - `Engineering-Developers`: developer
   - `Auditors`: auditor

### Step 5.3: Test Access

1. Get the SSO Start URL from Terraform output
2. Log in with a test user
3. Verify you can access assigned accounts

## Phase 6: Network Setup (Per Account)

### Step 6.1: Deploy VPC in Development Account

Create a new file `terraform/environments/workloads/dev/main.tf`:

```bash
cd terraform/environments
mkdir -p workloads/dev
```

```hcl
# workloads/dev/main.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-southeast-2"
  profile = "techcorp-admin"

  # If using member account, assume role
  # assume_role {
  #   role_arn = "arn:aws:iam::ACCOUNT_ID:role/OrganizationAccountAccessRole"
  # }
}

module "vpc" {
  source = "../../../modules/network/vpc"

  name_prefix   = "techcorp-dev"
  environment   = "development"
  vpc_cidr      = "10.102.0.0/16"
  number_of_azs = 2

  create_nat_gateway = false  # Cost savings for dev
  enable_flow_logs   = true
  enable_eks_tags    = false

  tags = {
    Department = "engineering"
    CostCenter = "CC-1001"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
```

## Phase 7: Verification & Testing

### Step 7.1: Verify Organization Setup

```bash
# List accounts
aws organizations list-accounts --profile techcorp-admin

# List OUs
aws organizations list-roots --profile techcorp-admin
aws organizations list-organizational-units-for-parent \
  --parent-id r-xxxx \
  --profile techcorp-admin
```

### Step 7.2: Verify Security Services

```bash
# Check CloudTrail
aws cloudtrail describe-trails --profile techcorp-admin

# Check GuardDuty
aws guardduty list-detectors --profile techcorp-admin
```

### Step 7.3: Verify IAM Identity Center

```bash
# List permission sets
aws sso-admin list-permission-sets \
  --instance-arn arn:aws:sso:::instance/ssoins-xxxxxxxx \
  --profile techcorp-admin
```

## Cost Management Tips

### Minimize Costs During Learning

1. **Don't create member accounts** - Use `create_accounts=false`
2. **Skip NAT Gateways** - They cost ~$32/month each
3. **Use single AZ** - Set `number_of_azs = 1` for dev
4. **Disable unused security features** - But keep CloudTrail enabled
5. **Clean up daily** - Destroy resources when not in use

### Cost Estimate (Minimal Setup)

| Component | Monthly Cost |
|-----------|-------------|
| S3 (Terraform state) | ~$1 |
| DynamoDB (locks) | ~$0 (free tier) |
| CloudTrail (organization) | ~$2 |
| GuardDuty | ~$4-10 |
| VPC Flow Logs | ~$5-10 |
| **Total** | **~$15-25/month** |

### Cost Estimate (Full Setup with Member Accounts)

| Component | Monthly Cost |
|-----------|-------------|
| 9 Member Accounts | $0 (no base cost) |
| NAT Gateways (if enabled) | ~$32 each |
| CloudTrail | ~$5-10 |
| GuardDuty (9 accounts) | ~$50-100 |
| Security Hub | ~$20-50 |
| VPC Flow Logs | ~$20-50 |
| **Total** | **~$150-300/month** |

## Cleanup / Teardown

### Quick Teardown (Development)

```bash
# Destroy in reverse order
cd terraform/environments/management
terraform destroy -var="aws_profile=techcorp-admin"

cd ../bootstrap
terraform destroy -var="aws_profile=techcorp-admin"
```

### Full Teardown (With Member Accounts)

> **Warning**: Member accounts cannot be deleted via Terraform!

1. Remove resources from each member account manually
2. Close member accounts in AWS Organizations console
3. Wait for accounts to be suspended (90 days until permanent deletion)
4. Then destroy the management account resources

See [RUNBOOKS.md](RUNBOOKS.md) for detailed cleanup procedures.

## Troubleshooting

### Common Issues

**Issue**: "AccessDenied" when creating organization
- **Solution**: Ensure you're using the root account credentials or an IAM user with OrganizationsFullAccess

**Issue**: "EntityAlreadyExists" for IAM Identity Center
- **Solution**: IAM Identity Center was already enabled. Import the existing resource or continue.

**Issue**: Account email already in use
- **Solution**: Each AWS account needs a unique email. Use email aliases.

**Issue**: SCP prevents action
- **Solution**: Check which SCP is blocking. SCPs are cumulative - a deny anywhere blocks the action.

### Getting Help

- [AWS Organizations Documentation](https://docs.aws.amazon.com/organizations/)
- [IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Next Steps

After completing this setup:

1. **Add more security controls**: AWS Config rules, Security Hub standards
2. **Set up CI/CD**: GitHub Actions for Terraform automation
3. **Configure budgets**: AWS Budgets with alerts
4. **Enable additional services**: EKS, RDS baselines
5. **Integrate external IdP**: Connect to Okta or Azure AD

---

*Implementation Guide Version 1.0*
