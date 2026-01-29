#!/bin/bash
# -----------------------------------------------------------------------------
# Cleanup Script for AWS Landing Zone
# WARNING: This script destroys resources! Use with caution.
# -----------------------------------------------------------------------------

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROFILE="${AWS_PROFILE:-techcorp-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${RED}============================================================${NC}"
echo -e "${RED}  AWS LANDING ZONE CLEANUP SCRIPT${NC}"
echo -e "${RED}============================================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This script will DESTROY all Terraform-managed resources!${NC}"
echo ""
echo "Using AWS Profile: $PROFILE"
echo ""

# Verify AWS access
echo "Verifying AWS access..."
if ! aws sts get-caller-identity --profile "$PROFILE" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot access AWS with profile '$PROFILE'${NC}"
    echo "Please ensure AWS_PROFILE is set correctly or run: export AWS_PROFILE=techcorp-admin"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text)
echo -e "${GREEN}✓ Connected to AWS Account: $ACCOUNT_ID${NC}"
echo ""

read -p "Are you sure you want to proceed with cleanup? (type 'yes' to confirm): " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Function to safely destroy terraform resources
destroy_terraform() {
    local dir=$1
    local name=$2

    if [ -d "$dir" ] && [ -f "$dir/main.tf" ]; then
        echo -e "${YELLOW}Destroying $name...${NC}"
        cd "$dir"

        if [ -f "terraform.tfstate" ] || [ -d ".terraform" ]; then
            terraform init -input=false > /dev/null 2>&1 || true
            terraform destroy -auto-approve -var="aws_profile=$PROFILE" || {
                echo -e "${YELLOW}Warning: Terraform destroy encountered issues in $name${NC}"
            }
        else
            echo "  No Terraform state found, skipping..."
        fi

        cd "$PROJECT_ROOT"
    else
        echo "  Directory $dir not found or has no main.tf, skipping..."
    fi
}

# Step 1: Destroy workload environments (if any)
echo ""
echo -e "${YELLOW}Step 1: Cleaning up workload environments...${NC}"
for env_dir in "$PROJECT_ROOT/terraform/environments/workloads"/*; do
    if [ -d "$env_dir" ]; then
        env_name=$(basename "$env_dir")
        destroy_terraform "$env_dir" "workloads/$env_name"
    fi
done

# Step 2: Destroy management account resources
echo ""
echo -e "${YELLOW}Step 2: Cleaning up management account resources...${NC}"
destroy_terraform "$PROJECT_ROOT/terraform/environments/management" "management"

# Step 3: Clean up S3 bucket contents before destroying bootstrap
echo ""
echo -e "${YELLOW}Step 3: Cleaning up S3 bucket contents...${NC}"
BUCKET_NAME="techcorp-terraform-state-ap-southeast-2"
if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$PROFILE" 2>/dev/null; then
    echo "  Emptying bucket: $BUCKET_NAME"
    aws s3 rm "s3://$BUCKET_NAME" --recursive --profile "$PROFILE" || true

    # Delete all object versions
    echo "  Deleting object versions..."
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --profile "$PROFILE" \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
        jq -c '.[]' 2>/dev/null | while read -r obj; do
            key=$(echo "$obj" | jq -r '.Key')
            version=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" --profile "$PROFILE" 2>/dev/null || true
        done

    # Delete all delete markers
    echo "  Deleting delete markers..."
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --profile "$PROFILE" \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
        jq -c '.[]' 2>/dev/null | while read -r obj; do
            key=$(echo "$obj" | jq -r '.Key')
            version=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" --profile "$PROFILE" 2>/dev/null || true
        done
else
    echo "  Bucket $BUCKET_NAME not found, skipping..."
fi

# Step 4: Destroy bootstrap resources
echo ""
echo -e "${YELLOW}Step 4: Cleaning up bootstrap resources...${NC}"
destroy_terraform "$PROJECT_ROOT/terraform/environments/bootstrap" "bootstrap"

# Step 5: Clean up local terraform files
echo ""
echo -e "${YELLOW}Step 5: Cleaning up local Terraform files...${NC}"
find "$PROJECT_ROOT/terraform" -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
find "$PROJECT_ROOT/terraform" -type f -name "terraform.tfstate*" -delete 2>/dev/null || true
find "$PROJECT_ROOT/terraform" -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "1. Member AWS accounts (if created) cannot be deleted automatically"
echo "   - You must close them manually in AWS Organizations console"
echo "   - Sign in to each account and close via Account Settings"
echo ""
echo "2. Some resources may still exist if they were created outside Terraform"
echo "   - Check AWS Console for any remaining resources"
echo ""
echo "3. CloudTrail logs in S3 will remain until bucket is deleted"
echo "   - GuardDuty findings export bucket may also remain"
echo ""
echo "4. AWS Organizations will remain (cannot be deleted, only disabled)"
echo ""
