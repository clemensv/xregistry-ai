# Azure Static Web Apps Deployment Guide

This guide will help you deploy the xRegistry project to Azure Static Web Apps using the automated GitHub Actions workflow.

## Overview

The deployment consists of:
- **Frontend**: Angular SPA from `clemensv/xregistry-viewer` repository
- **Registry Data**: Static JSON files from the `static-site` branch of this repository
- **API**: Served as static JSON files with proper CORS configuration

## Prerequisites

- Azure subscription with permission to create resources
- GitHub repository with Actions enabled
- Azure CLI (optional, for command-line setup)

## Step 1: Create Azure Static Web App

### Option A: Azure Portal (Recommended)

1. **Navigate to Azure Portal**
   - Go to [portal.azure.com](https://portal.azure.com)
   - Sign in with your Azure account

2. **Create Resource**
   - Click "Create a resource"
   - Search for "Static Web App"
   - Select "Static Web App" by Microsoft

3. **Configure Basic Settings**
   ```
   Subscription: [Your subscription]
   Resource Group: [Create new or use existing]
   Name: xregistry-static-app
   Plan type: Free (or Standard if needed)
   Region: [Choose closest to your users]
   ```

4. **Configure Deployment**
   ```
   Source: GitHub
   GitHub account: [Your GitHub account]
   Organization: clemensv
   Repository: xregistry-ai
   Branch: main
   ```

5. **Build Configuration**
   ```
   Build Presets: Angular
   App location: /
   API location: [Leave empty]
   Output location: dist/xregistry-viewer
   ```

6. **Review and Create**
   - Review all settings
   - Click "Create"
   - Wait for deployment to complete (2-3 minutes)

### Option B: Azure CLI

```bash
# Login to Azure
az login

# Create resource group (if needed)
az group create --name xregistry-rg --location "East US"

# Create Static Web App
az staticwebapp create \
  --name xregistry-static-app \
  --resource-group xregistry-rg \
  --source https://github.com/clemensv/xregistry-ai \
  --location "East US" \
  --branch main \
  --app-location "/" \
  --output-location "dist/xregistry-viewer"
```

## Step 2: Configure GitHub Secrets

After creating the Azure Static Web App, you need to configure GitHub with the deployment token.

### Get Deployment Token

1. **From Azure Portal**
   - Navigate to your Static Web App resource
   - Go to "Overview" → "Manage deployment token"
   - Click "Copy" to copy the token

2. **From Azure CLI**
   ```bash
   az staticwebapp secrets list --name xregistry-static-app --resource-group xregistry-rg
   ```

### Add GitHub Secret

1. **Navigate to GitHub Repository**
   - Go to `https://github.com/clemensv/xregistry-ai`
   - Click "Settings" → "Secrets and variables" → "Actions"

2. **Add Repository Secret**
   - Click "New repository secret"
   - Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
   - Value: [Paste the deployment token from Azure]
   - Click "Add secret"

## Step 3: Configure GitHub Variables

Enable the Azure deployment by setting the required variable:

1. **In GitHub Repository Settings**
   - Go to "Settings" → "Secrets and variables" → "Actions"
   - Click the "Variables" tab
   - Click "New repository variable"

2. **Add Variable**
   - Name: `ENABLE_AZURE_DEPLOYMENT`
   - Value: `true`
   - Click "Add variable"

## Step 4: Test the Deployment

### Trigger Manual Deployment

1. **Navigate to Actions**
   - Go to GitHub repository → "Actions" tab
   - Find "Deploy to Azure Static Web Apps" workflow

2. **Run Workflow**
   - Click "Run workflow" dropdown
   - Leave default settings
   - Click "Run workflow" button

### Monitor Deployment

The workflow will:
1. ✅ Check Azure configuration
2. ✅ Checkout the Angular SPA repository
3. ✅ Checkout the static-site branch with registry data
4. ✅ Configure Angular for Azure deployment
5. ✅ Setup Azure Static Web App configuration
6. ✅ Build and deploy to Azure

## Step 5: Verify Deployment

### Check Deployment Status

1. **GitHub Actions**
   - Monitor the workflow in GitHub Actions
   - Look for success indicators
   - Note the deployment URL in the logs

2. **Azure Portal**
   - Go to your Static Web App resource
   - Check "Functions" tab for deployment status
   - Note the URL under "URL" section

### Test the Application

1. **Frontend Application**
   - Visit the Azure Static Web App URL
   - Verify the Angular application loads
   - Test navigation and functionality

2. **Registry API**
   - Test registry endpoints: `https://your-app.azurestaticapps.net/registry/`
   - Verify JSON data is accessible
   - Check CORS headers are working

### Example URLs

```
Application: https://xregistry-static-app.azurestaticapps.net/
Registry API: https://xregistry-static-app.azurestaticapps.net/registry/
MCP Providers: https://xregistry-static-app.azurestaticapps.net/registry/mcpproviders/
Agent Cards: https://xregistry-static-app.azurestaticapps.net/registry/agentcardproviders/
```

## Automatic Deployment

Once configured, the deployment will automatically trigger when:

1. **Static Site Build Completes**
   - After the "Build static content into static-site branch" workflow succeeds
   - Registry content is updated
   - Angular app is rebuilt and deployed

2. **Manual Trigger**
   - You can manually run the deployment workflow
   - Useful for testing or emergency deployments

## Configuration Files

The deployment uses several configuration files:

### Azure Static Web App Configurations

- **`xreg/root-staticwebapp.config.json`** - Main app configuration
  - Route handling for Angular SPA
  - CORS headers
  - MIME types

- **`xreg/registry-staticwebapp.config.json`** - Registry API configuration
  - Caching headers for JSON files
  - CORS configuration for registry endpoints
  - Default document handling

### Angular Configuration

The workflow automatically:
- Updates `config.json` with proper base URL
- Modifies `environment.prod.ts` for Azure paths
- Configures routing for static hosting

## Troubleshooting

### Common Issues

1. **Deployment Token Invalid**
   ```
   Error: Invalid deployment token
   Solution: Regenerate token in Azure portal and update GitHub secret
   ```

2. **Build Failures**
   ```
   Error: Angular build failed
   Solution: Check the static-site branch has valid content
   ```

3. **CORS Issues**
   ```
   Error: Access denied from origin
   Solution: Verify Azure config files are properly deployed
   ```

### Debug Steps

1. **Check Workflow Logs**
   - Look at detailed logs in GitHub Actions
   - Identify specific failure points

2. **Verify Azure Configuration**
   - Check Static Web App settings in Azure portal
   - Verify custom domain and routing rules

3. **Test Registry Endpoints**
   - Manually test JSON endpoints
   - Check browser network tab for errors

## Monitoring and Maintenance

### Azure Insights

- Enable Application Insights for monitoring
- Set up alerts for deployment failures
- Monitor performance and usage

### GitHub Actions

- Monitor workflow success rates
- Set up notifications for deployment failures
- Review logs for optimization opportunities

### Cost Management

- Free tier includes:
  - 100 GB bandwidth per month
  - 0.5 GB storage
  - Custom domains

- Monitor usage in Azure portal
- Upgrade to Standard if needed for higher limits

## Security Considerations

### HTTPS and Security Headers

- Azure Static Web Apps provides automatic HTTPS
- Security headers are configured in `staticwebapp.config.json`
- HSTS headers enforce secure connections

### Access Control

- Current setup allows public access to registry
- Can be configured for authentication if needed
- API routes can be protected with Azure Functions

### Secrets Management

- Deployment tokens are stored as GitHub secrets
- Azure provides automatic secret rotation
- Monitor access logs for security events

## Next Steps

1. **Custom Domain** (Optional)
   - Configure custom domain in Azure portal
   - Set up DNS records
   - Verify SSL certificate

2. **API Functions** (Optional)
   - Add Azure Functions for dynamic API endpoints
   - Implement authentication and authorization
   - Add database integration

3. **Monitoring and Analytics**
   - Enable Application Insights
   - Set up custom dashboards
   - Configure alerts and notifications

## Support

- **Azure Documentation**: [Azure Static Web Apps docs](https://docs.microsoft.com/en-us/azure/static-web-apps/)
- **GitHub Actions**: [Azure Static Web Apps deploy action](https://github.com/Azure/static-web-apps-deploy)
- **xRegistry Project**: Create issues in the GitHub repository for project-specific questions 