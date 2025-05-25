# Commit Azure configuration changes and trigger deployment
Set-Location "C:\git\ai\xregistry-ai"

Write-Host "Adding changed files..."
git add xreg/root-staticwebapp.config.json xreg/registry-staticwebapp.config.json

Write-Host "Committing changes..."
git commit -m "Fix Azure Static Web Apps routing: serve index.json by default for /registry/ paths

- Add explicit routing rules for /registry/ and subdirectories
- Configure rewrites to serve index.json for directory paths
- This should fix 404 errors and make https://victorious-river-003c3d70f.6.azurestaticapps.net/registry/ work correctly"

Write-Host "Pushing to origin..."
git push origin main

Write-Host "Triggering Azure deployment workflow..."
gh workflow run "Deploy to Azure Static Web Apps" --field use_existing_static_site=true

Write-Host "Configuration changes committed and deployment triggered!"
Write-Host "The changes should resolve the 404 issue at /registry/ paths." 