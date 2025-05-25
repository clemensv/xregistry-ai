# Azure Static Web App Setup Script for xRegistry (PowerShell)
# This script automates the creation of Azure Static Web App and GitHub configuration

# Stop on any error
$ErrorActionPreference = "Stop"

# Configuration
$RESOURCE_GROUP_NAME = "xregistry-rg"
$STATIC_APP_NAME = "xregistry-static-app"
$LOCATION = "East US 2"
$GITHUB_REPO = "clemensv/xregistry-ai"
$GITHUB_TOKEN_SECRET_NAME = "AZURE_STATIC_WEB_APPS_API_TOKEN"

Write-Host "🚀 Azure Static Web App Setup for xRegistry" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host ""

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

# Check if Azure CLI is installed
try {
    az --version | Out-Null
    Write-Host "✅ Azure CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI is not installed" -ForegroundColor Red
    Write-Host "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if GitHub CLI is installed
try {
    gh --version | Out-Null
    Write-Host "✅ GitHub CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI is not installed" -ForegroundColor Red
    Write-Host "Please install GitHub CLI: https://github.com/cli/cli#installation"
    exit 1
}

# Check Azure login status
Write-Host "🔐 Checking Azure authentication..." -ForegroundColor Yellow
try {
    $azureAccount = az account show --query name -o tsv
    Write-Host "✅ Logged into Azure as: $azureAccount" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Not logged into Azure. Please login:" -ForegroundColor Yellow
    az login
    $azureAccount = az account show --query name -o tsv
    Write-Host "✅ Logged into Azure as: $azureAccount" -ForegroundColor Green
}

# Check GitHub authentication
Write-Host "🔐 Checking GitHub authentication..." -ForegroundColor Yellow
try {
    gh auth status 2>$null | Out-Null
    $ghUser = gh api user --jq '.login' 2>$null
    if (-not $ghUser) { $ghUser = "unknown" }
    Write-Host "✅ Logged into GitHub as: $ghUser" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Not logged into GitHub. Please login:" -ForegroundColor Yellow
    gh auth login
    $ghUser = gh api user --jq '.login' 2>$null
    if (-not $ghUser) { $ghUser = "unknown" }
    Write-Host "✅ Logged into GitHub as: $ghUser" -ForegroundColor Green
}
Write-Host ""

# Prompt for resource group creation
Write-Host "📦 Resource Group Configuration" -ForegroundColor Yellow
$createRg = Read-Host "Create new resource group '$RESOURCE_GROUP_NAME'? (y/n)"

if ($createRg -match "^[Yy]$") {
    Write-Host "🏗️  Creating resource group: $RESOURCE_GROUP_NAME" -ForegroundColor Yellow
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
    Write-Host "✅ Resource group created" -ForegroundColor Green
} else {
    # List existing resource groups
    Write-Host "Available resource groups:" -ForegroundColor Blue
    az group list --query "[].name" -o table
    $RESOURCE_GROUP_NAME = Read-Host "Enter resource group name"
}
Write-Host ""

# Create Static Web App
Write-Host "🌐 Creating Azure Static Web App" -ForegroundColor Yellow
Write-Host "Name: $STATIC_APP_NAME"
Write-Host "Resource Group: $RESOURCE_GROUP_NAME"
Write-Host "Location: $LOCATION"
Write-Host "GitHub Repo: $GITHUB_REPO"
Write-Host ""

$createApp = Read-Host "Proceed with creation? (y/n)"

if ($createApp -match "^[Yy]$") {
    Write-Host "🏗️  Creating Static Web App..." -ForegroundColor Yellow
    
    # Create the static web app
    try {
        az staticwebapp create `
            --name $STATIC_APP_NAME `
            --resource-group $RESOURCE_GROUP_NAME `
            --source "https://github.com/$GITHUB_REPO" `
            --location $LOCATION `
            --branch main `
            --app-location "/" `
            --output-location "dist/xregistry-viewer" `
            --login-with-github
        
        Write-Host "✅ Static Web App created successfully" -ForegroundColor Green
        
        # Get the app URL
        $appUrl = az staticwebapp show --name $STATIC_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query "defaultHostname" -o tsv
        Write-Host "🌐 App URL: https://$appUrl" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to create Static Web App" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠️  Skipping Static Web App creation" -ForegroundColor Yellow
    # Get existing app URL
    try {
        $appUrl = az staticwebapp show --name $STATIC_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query "defaultHostname" -o tsv
    } catch {
        Write-Host "❌ Could not find existing Static Web App" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Get deployment token
Write-Host "🔑 Retrieving deployment token..." -ForegroundColor Yellow
try {
    $deploymentToken = az staticwebapp secrets list --name $STATIC_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query "properties.apiKey" -o tsv
    
    if ($deploymentToken) {
        Write-Host "✅ Deployment token retrieved" -ForegroundColor Green
    } else {
        throw "Empty deployment token"
    }
} catch {
    Write-Host "❌ Failed to retrieve deployment token" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Configure GitHub secrets and variables
Write-Host "🔐 Configuring GitHub repository..." -ForegroundColor Yellow

# Add deployment token as secret
Write-Host "Adding deployment token as GitHub secret..."
try {
    $deploymentToken | gh secret set $GITHUB_TOKEN_SECRET_NAME --repo $GITHUB_REPO
    Write-Host "✅ GitHub secret '$GITHUB_TOKEN_SECRET_NAME' created" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create GitHub secret" -ForegroundColor Red
    exit 1
}

# Set ENABLE_AZURE_DEPLOYMENT variable
Write-Host "Setting ENABLE_AZURE_DEPLOYMENT variable..."
try {
    "true" | gh variable set ENABLE_AZURE_DEPLOYMENT --repo $GITHUB_REPO
    Write-Host "✅ GitHub variable 'ENABLE_AZURE_DEPLOYMENT' set to 'true'" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to set GitHub variable" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test deployment workflow
Write-Host "🧪 Testing deployment workflow..." -ForegroundColor Yellow
$triggerDeploy = Read-Host "Trigger a test deployment now? (y/n)"

if ($triggerDeploy -match "^[Yy]$") {
    Write-Host "🚀 Triggering deployment workflow..." -ForegroundColor Yellow
    
    try {
        gh workflow run "deploy-azure-static.yml" --repo $GITHUB_REPO
        Write-Host "✅ Deployment workflow triggered" -ForegroundColor Green
        Write-Host "🔍 Monitor progress at: https://github.com/$GITHUB_REPO/actions" -ForegroundColor Blue
    } catch {
        Write-Host "❌ Failed to trigger deployment workflow" -ForegroundColor Red
    }
}
Write-Host ""

# Summary
Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host "===============" -ForegroundColor Blue
Write-Host ""
Write-Host "✅ Azure Static Web App: $STATIC_APP_NAME" -ForegroundColor Green
Write-Host "✅ Resource Group: $RESOURCE_GROUP_NAME" -ForegroundColor Green
Write-Host "✅ GitHub Secret: $GITHUB_TOKEN_SECRET_NAME" -ForegroundColor Green
Write-Host "✅ GitHub Variable: ENABLE_AZURE_DEPLOYMENT = true" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Application URL: https://$appUrl" -ForegroundColor Blue

# Get subscription ID for Azure portal link
$subscriptionId = az account show --query id -o tsv
Write-Host "📊 Azure Portal: https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Web/staticSites/$STATIC_APP_NAME" -ForegroundColor Blue
Write-Host "🔧 GitHub Actions: https://github.com/$GITHUB_REPO/actions" -ForegroundColor Blue
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Monitor the deployment workflow in GitHub Actions"
Write-Host "2. Test the application at the provided URL"
Write-Host "3. Configure custom domain (optional)"
Write-Host "4. Set up monitoring and alerts"
Write-Host ""
Write-Host "🚀 Your xRegistry is now ready for Azure deployment!" -ForegroundColor Green