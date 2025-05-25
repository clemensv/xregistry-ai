#!/bin/bash

# Azure Static Web App Setup Script for xRegistry
# This script automates the creation of Azure Static Web App and GitHub configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP_NAME="xregistry-rg"
STATIC_APP_NAME="xregistry-static-app"
LOCATION="East US 2"
GITHUB_REPO="clemensv/xregistry-ai"
GITHUB_TOKEN_SECRET_NAME="AZURE_STATIC_WEB_APPS_API_TOKEN"

echo -e "${BLUE}🚀 Azure Static Web App Setup for xRegistry${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI found${NC}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not installed${NC}"
    echo "Please install GitHub CLI: https://github.com/cli/cli#installation"
    exit 1
fi
echo -e "${GREEN}✅ GitHub CLI found${NC}"

# Check Azure login status
echo -e "${YELLOW}🔐 Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged into Azure. Please login:${NC}"
    az login
fi

AZURE_ACCOUNT=$(az account show --query name -o tsv)
echo -e "${GREEN}✅ Logged into Azure as: $AZURE_ACCOUNT${NC}"

# Check GitHub authentication
echo -e "${YELLOW}🔐 Checking GitHub authentication...${NC}"
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged into GitHub. Please login:${NC}"
    gh auth login
fi

GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
echo -e "${GREEN}✅ Logged into GitHub as: $GH_USER${NC}"
echo ""

# Prompt for resource group creation
echo -e "${YELLOW}📦 Resource Group Configuration${NC}"
read -p "Create new resource group '$RESOURCE_GROUP_NAME'? (y/n): " create_rg

if [[ $create_rg =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🏗️  Creating resource group: $RESOURCE_GROUP_NAME${NC}"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    echo -e "${GREEN}✅ Resource group created${NC}"
else
    # List existing resource groups
    echo -e "${BLUE}Available resource groups:${NC}"
    az group list --query "[].name" -o table
    read -p "Enter resource group name: " RESOURCE_GROUP_NAME
fi
echo ""

# Create Static Web App
echo -e "${YELLOW}🌐 Creating Azure Static Web App${NC}"
echo "Name: $STATIC_APP_NAME"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo "GitHub Repo: $GITHUB_REPO"
echo ""

read -p "Proceed with creation? (y/n): " create_app

if [[ $create_app =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🏗️  Creating Static Web App...${NC}"
    
    # Create the static web app
    CREATION_OUTPUT=$(az staticwebapp create \
        --name "$STATIC_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --source "https://github.com/$GITHUB_REPO" \
        --location "$LOCATION" \
        --branch main \
        --app-location "/" \
        --output-location "dist/xregistry-viewer" \
        --login-with-github)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Static Web App created successfully${NC}"
        
        # Get the app URL
        APP_URL=$(az staticwebapp show --name "$STATIC_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "defaultHostname" -o tsv)
        echo -e "${GREEN}🌐 App URL: https://$APP_URL${NC}"
    else
        echo -e "${RED}❌ Failed to create Static Web App${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Skipping Static Web App creation${NC}"
fi
echo ""

# Get deployment token
echo -e "${YELLOW}🔑 Retrieving deployment token...${NC}"
DEPLOYMENT_TOKEN=$(az staticwebapp secrets list --name "$STATIC_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "properties.apiKey" -o tsv)

if [ -n "$DEPLOYMENT_TOKEN" ]; then
    echo -e "${GREEN}✅ Deployment token retrieved${NC}"
else
    echo -e "${RED}❌ Failed to retrieve deployment token${NC}"
    exit 1
fi
echo ""

# Configure GitHub secrets and variables
echo -e "${YELLOW}🔐 Configuring GitHub repository...${NC}"

# Add deployment token as secret
echo "Adding deployment token as GitHub secret..."
echo "$DEPLOYMENT_TOKEN" | gh secret set "$GITHUB_TOKEN_SECRET_NAME" --repo "$GITHUB_REPO"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ GitHub secret '$GITHUB_TOKEN_SECRET_NAME' created${NC}"
else
    echo -e "${RED}❌ Failed to create GitHub secret${NC}"
    exit 1
fi

# Set ENABLE_AZURE_DEPLOYMENT variable
echo "Setting ENABLE_AZURE_DEPLOYMENT variable..."
echo "true" | gh variable set ENABLE_AZURE_DEPLOYMENT --repo "$GITHUB_REPO"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ GitHub variable 'ENABLE_AZURE_DEPLOYMENT' set to 'true'${NC}"
else
    echo -e "${RED}❌ Failed to set GitHub variable${NC}"
    exit 1
fi
echo ""

# Test deployment workflow
echo -e "${YELLOW}🧪 Testing deployment workflow...${NC}"
read -p "Trigger a test deployment now? (y/n): " trigger_deploy

if [[ $trigger_deploy =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🚀 Triggering deployment workflow...${NC}"
    
    gh workflow run "deploy-azure-static.yml" --repo "$GITHUB_REPO"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Deployment workflow triggered${NC}"
        echo -e "${BLUE}🔍 Monitor progress at: https://github.com/$GITHUB_REPO/actions${NC}"
    else
        echo -e "${RED}❌ Failed to trigger deployment workflow${NC}"
    fi
fi
echo ""

# Summary
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo -e "${BLUE}===============${NC}"
echo ""
echo -e "${GREEN}✅ Azure Static Web App: $STATIC_APP_NAME${NC}"
echo -e "${GREEN}✅ Resource Group: $RESOURCE_GROUP_NAME${NC}"
echo -e "${GREEN}✅ GitHub Secret: $GITHUB_TOKEN_SECRET_NAME${NC}"
echo -e "${GREEN}✅ GitHub Variable: ENABLE_AZURE_DEPLOYMENT = true${NC}"
echo ""
echo -e "${BLUE}🌐 Application URL: https://$APP_URL${NC}"
echo -e "${BLUE}📊 Azure Portal: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Web/staticSites/$STATIC_APP_NAME${NC}"
echo -e "${BLUE}🔧 GitHub Actions: https://github.com/$GITHUB_REPO/actions${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Monitor the deployment workflow in GitHub Actions"
echo "2. Test the application at the provided URL"
echo "3. Configure custom domain (optional)"
echo "4. Set up monitoring and alerts"
echo ""
echo -e "${GREEN}🚀 Your xRegistry is now ready for Azure deployment!${NC}" 