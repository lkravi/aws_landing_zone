#!/bin/bash
# -----------------------------------------------------------------------------
# AWS Profile Setup Script for TechCorp Landing Zone Project
# This script helps you configure a dedicated AWS profile for this project
# -----------------------------------------------------------------------------

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROFILE_NAME="${1:-techcorp-admin}"

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  AWS Profile Setup for Landing Zone Project${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    echo "Please install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

echo -e "${YELLOW}This script will help you set up a dedicated AWS profile: ${PROFILE_NAME}${NC}"
echo ""
echo "Prerequisites:"
echo "  1. A new AWS account created (this will be your Management Account)"
echo "  2. IAM user with AdministratorAccess policy attached"
echo "  3. Access Key ID and Secret Access Key for that IAM user"
echo ""
echo -e "${YELLOW}Note: After AWS Organizations is set up, we'll switch to IAM Identity Center${NC}"
echo -e "${YELLOW}      and remove this IAM user for security.${NC}"
echo ""

read -p "Do you want to configure the AWS profile now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Running: aws configure --profile ${PROFILE_NAME}"
    echo ""
    aws configure --profile ${PROFILE_NAME}

    echo ""
    echo -e "${GREEN}Profile configured successfully!${NC}"
    echo ""

    # Verify the profile works
    echo "Verifying profile access..."
    if aws sts get-caller-identity --profile ${PROFILE_NAME} > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Profile is working correctly${NC}"
        echo ""
        aws sts get-caller-identity --profile ${PROFILE_NAME}
    else
        echo -e "${RED}✗ Could not verify profile. Please check your credentials.${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Next Steps${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "1. Set the profile for this terminal session:"
echo -e "   ${YELLOW}export AWS_PROFILE=${PROFILE_NAME}${NC}"
echo ""
echo "2. Or add to your shell profile (~/.bashrc or ~/.zshrc):"
echo -e "   ${YELLOW}echo 'export AWS_PROFILE=${PROFILE_NAME}' >> ~/.zshrc${NC}"
echo ""
echo "3. Navigate to bootstrap directory and initialize Terraform:"
echo -e "   ${YELLOW}cd terraform/environments/bootstrap${NC}"
echo -e "   ${YELLOW}terraform init${NC}"
echo -e "   ${YELLOW}terraform plan${NC}"
echo -e "   ${YELLOW}terraform apply${NC}"
echo ""
echo -e "${GREEN}============================================================${NC}"
