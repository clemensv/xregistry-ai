# Scripts Directory

This directory contains automation scripts for setting up and managing the xRegistry project deployment.

## Azure Static Web Apps Deployment

### Setup Scripts

- **`setup-azure-deployment.sh`** - Bash script for Linux/macOS
- **`setup-azure-deployment.ps1`** - PowerShell script for Windows

These scripts automate the creation of Azure Static Web Apps and GitHub configuration for automated deployment.

### What the Scripts Do

1. **Check Prerequisites**
   - Verify Azure CLI is installed
   - Verify GitHub CLI is installed
   - Check authentication status for both services

2. **Create Azure Resources**
   - Create resource group (optional)
   - Create Azure Static Web App
   - Configure deployment settings

3. **Configure GitHub Integration**
   - Add Azure deployment token as GitHub secret
   - Set GitHub repository variables
   - Enable automated deployment

4. **Test Deployment**
   - Optionally trigger a test deployment
   - Provide monitoring links and next steps

### Prerequisites

Before running either script, ensure you have:

- **Azure CLI** installed and configured
  - Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
  - Login: `az login`

- **GitHub CLI** installed and authenticated
  - Install: https://github.com/cli/cli#installation
  - Login: `gh auth login`

- **Permissions**
  - Azure subscription with Static Web Apps creation permissions
  - GitHub repository access with Actions and Secrets permissions

### Usage

#### Linux/macOS (Bash)
```bash
# Make script executable
chmod +x scripts/setup-azure-deployment.sh

# Run the script
./scripts/setup-azure-deployment.sh
```

#### Windows (PowerShell)
```powershell
# Run the script
.\scripts\setup-azure-deployment.ps1
```

### Configuration

The scripts use these default values (you can modify them in the script):

```bash
RESOURCE_GROUP_NAME="xregistry-rg"
STATIC_APP_NAME="xregistry-static-app"
LOCATION="East US"
GITHUB_REPO="clemensv/xregistry-ai"
GITHUB_TOKEN_SECRET_NAME="AZURE_STATIC_WEB_APPS_API_TOKEN"
```

### Output

After successful execution, you'll have:

- ✅ Azure Static Web App created
- ✅ GitHub secret `AZURE_STATIC_WEB_APPS_API_TOKEN` configured
- ✅ GitHub variable `ENABLE_AZURE_DEPLOYMENT` set to `true`
- ✅ Deployment workflow ready to run

### Deployment Workflow

The Azure deployment uses the existing `.github/workflows/deploy-azure-static.yml` workflow which:

1. Checks out the Angular SPA from `clemensv/xregistry-viewer`
2. Checks out the registry content from the `static-site` branch
3. Configures the Angular app for Azure hosting
4. Builds and deploys to Azure Static Web Apps
5. Provides deployment status and URLs

### Troubleshooting

#### Common Issues

1. **Authentication Errors**
   ```
   Error: Not authenticated
   Solution: Run az login and gh auth login
   ```

2. **Permission Denied**
   ```
   Error: Insufficient permissions
   Solution: Ensure you have Azure and GitHub permissions
   ```

3. **Resource Already Exists**
   ```
   Error: Static Web App name already taken
   Solution: Modify STATIC_APP_NAME in the script
   ```

#### Manual Configuration

If the script fails, you can manually configure:

1. **Create Azure Static Web App** in the Azure portal
2. **Copy deployment token** from Azure
3. **Add GitHub secret** `AZURE_STATIC_WEB_APPS_API_TOKEN`
4. **Set GitHub variable** `ENABLE_AZURE_DEPLOYMENT = true`

### Monitoring

After setup, monitor deployments at:

- **GitHub Actions**: https://github.com/clemensv/xregistry-ai/actions
- **Azure Portal**: View your Static Web App resource
- **Application URL**: Provided in script output

### Additional Resources

- [Azure Static Web Apps Documentation](https://docs.microsoft.com/en-us/azure/static-web-apps/)
- [GitHub Actions for Azure](https://docs.microsoft.com/en-us/azure/static-web-apps/github-actions-workflow)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/staticwebapp)
- [GitHub CLI Reference](https://cli.github.com/manual/) 