# Simple deployment script for xRegistry AI (PowerShell version)
# This bypasses the complex xRegistry server setup and creates a basic static site

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$LiveDir = Join-Path $RepoRoot "live"

Write-Host "🚀 Starting simplified xRegistry AI deployment..." -ForegroundColor Green
Write-Host "Repository root: $RepoRoot"

# Clean up previous builds
Write-Host "🧹 Cleaning up previous builds..." -ForegroundColor Yellow
if (Test-Path $LiveDir) {
    Remove-Item -Recurse -Force $LiveDir
}
New-Item -ItemType Directory -Path $LiveDir -Force | Out-Null

# Generate search indices
Write-Host "📊 Generating search indices..." -ForegroundColor Cyan
Set-Location (Join-Path $RepoRoot "index")
try {
    python build_index.py
} catch {
    Write-Host "⚠️  Index generation had warnings (npm not available)" -ForegroundColor Yellow
}

# Copy registry structure to live directory
Write-Host "📁 Copying registry structure..." -ForegroundColor Cyan
$RegistryPath = Join-Path $RepoRoot "registry"
if (Test-Path $RegistryPath) {
    Copy-Item -Path "$RegistryPath\*" -Destination $LiveDir -Recurse -Force
}

# Copy generated indices
Write-Host "📋 Copying search indices..." -ForegroundColor Cyan
$IndexPath = Join-Path $RepoRoot "index"
Get-ChildItem -Path $IndexPath -Filter "*.json" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $LiveDir -Force
}

# Generate schemas
Write-Host "🔧 Generating schemas..." -ForegroundColor Cyan
Set-Location (Join-Path $RepoRoot "xreg")
$SchemaDir = Join-Path $RepoRoot "schema"
$OpenApiDir = Join-Path $RepoRoot "openapi"
New-Item -ItemType Directory -Path $SchemaDir -Force | Out-Null
New-Item -ItemType Directory -Path $OpenApiDir -Force | Out-Null

# Generate schemas using the schema generator
try {
    python schema-generator.py --models --type json-schema --output (Join-Path $SchemaDir "json-schema.json")
} catch {
    Write-Host "⚠️  JSON schema generation failed" -ForegroundColor Yellow
}

try {
    python schema-generator.py --models --type openapi --output (Join-Path $OpenApiDir "openapi.json")
} catch {
    Write-Host "⚠️  OpenAPI generation failed" -ForegroundColor Yellow
}

try {
    python schema-generator.py --models --type avro-schema --output (Join-Path $SchemaDir "avro-schema.json")
} catch {
    Write-Host "⚠️  Avro schema generation failed" -ForegroundColor Yellow
}

# Copy schemas to live directory
Write-Host "📄 Copying schemas..." -ForegroundColor Cyan
$LiveSchemaDir = Join-Path $LiveDir "schema"
$LiveOpenApiDir = Join-Path $LiveDir "openapi"
New-Item -ItemType Directory -Path $LiveSchemaDir -Force | Out-Null
New-Item -ItemType Directory -Path $LiveOpenApiDir -Force | Out-Null

if (Test-Path $SchemaDir) {
    Get-ChildItem -Path $SchemaDir -Filter "*.json" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $LiveSchemaDir -Force
    }
}

if (Test-Path $OpenApiDir) {
    Get-ChildItem -Path $OpenApiDir -Filter "*.json" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $LiveOpenApiDir -Force
    }
}

# Copy Azure configuration
Write-Host "⚙️  Copying Azure configuration..." -ForegroundColor Cyan
$AzureConfigPath = Join-Path $RepoRoot "xreg\registry-staticwebapp.config.json"
if (Test-Path $AzureConfigPath) {
    Copy-Item -Path $AzureConfigPath -Destination (Join-Path $LiveDir "staticwebapp.config.json") -Force
}

# Create a simple info file
Write-Host "ℹ️  Creating deployment info..." -ForegroundColor Cyan
$McpProviderCount = (Get-ChildItem -Path (Join-Path $RepoRoot "registry\mcpproviders") -Filter "index.json" -Recurse).Count
$AgentCardProviderCount = (Get-ChildItem -Path (Join-Path $RepoRoot "registry\agentcardproviders") -Filter "index.json" -Recurse).Count
$IndexFileCount = (Get-ChildItem -Path $LiveDir -Filter "*.json").Count

$DeploymentInfo = @{
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    version = "simplified-deployment"
    generator = "simple-deploy.ps1"
    registry = @{
        mcpProviders = $McpProviderCount
        agentCardProviders = $AgentCardProviderCount
    }
} | ConvertTo-Json -Depth 3

$DeploymentInfo | Out-File -FilePath (Join-Path $LiveDir "deployment-info.json") -Encoding UTF8

# Display summary
Write-Host ""
Write-Host "✅ Simplified deployment completed!" -ForegroundColor Green
Write-Host "📁 Live directory: $LiveDir"
Write-Host "📊 Registry structure:"
Get-ChildItem -Path $LiveDir | Select-Object -First 20 | Format-Table Name, Length, LastWriteTime
Write-Host ""
Write-Host "🔍 Registry content summary:" -ForegroundColor Cyan
Write-Host "   - MCP Providers: $McpProviderCount providers"
Write-Host "   - Agent Card Providers: $AgentCardProviderCount providers"
Write-Host "   - Search indices: $IndexFileCount files"
Write-Host ""
Write-Host "🌐 Ready for deployment to:" -ForegroundColor Green
Write-Host "   - GitHub Pages"
Write-Host "   - Azure Static Web Apps"
Write-Host "   - Any static hosting service" 