# PowerShell wrapper for the MCP workflow test
# This script calls the bash version but provides PowerShell-friendly interface

param(
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$RepoOwner = "clemensv",
    [string]$RepoName = "xregistry-ai",
    [switch]$Help
)

function Show-Help {
    Write-Host @"
MCP Workflow Test - PowerShell Wrapper

DESCRIPTION:
    Tests the MCP (Model Context Protocol) submission workflow by creating a GitHub issue
    and validating that the GitHub Actions workflow processes it correctly.

USAGE:
    .\test-mcp-workflow.ps1 [-GitHubToken <token>] [-RepoOwner <owner>] [-RepoName <repo>] [-Help]

PARAMETERS:
    -GitHubToken    GitHub personal access token (optional if already logged in with 'gh auth login')
    -RepoOwner      Repository owner (default: clemensv)
    -RepoName       Repository name (default: xregistry-ai)
    -Help           Show this help message

EXAMPLES:
    # Using existing GitHub CLI authentication
    .\test-mcp-workflow.ps1

    # Passing token as parameter (if not logged in)
    .\test-mcp-workflow.ps1 -GitHubToken "ghp_xxxxxxxxxxxx"

    # Testing different repository
    .\test-mcp-workflow.ps1 -RepoOwner "myorg" -RepoName "myrepo"

PREREQUISITES:
    1. GitHub CLI (gh) must be installed
    2. Git Bash must be available (usually installed with Git for Windows)
    3. Either:
       - Be logged in with 'gh auth login', or
       - Provide a GitHub personal access token with repo permissions

"@
}

function Test-Prerequisites {
    # Check if GitHub CLI is available
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
        return $false
    }

    # Check if bash is available (Git Bash)
    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Error "Bash is not available. Please ensure Git for Windows is installed."
        return $false
    }

    # Check GitHub authentication status
    try {
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitHub CLI is already authenticated" -ForegroundColor Green
            return $true
        }
    }
    catch {
        # gh auth status failed, not authenticated
    }

    # If not authenticated, check if GitHub token is provided
    if (-not $GitHubToken) {
        Write-Error "GitHub CLI is not authenticated and no token provided."
        Write-Error "Please either:"
        Write-Error "  1. Run 'gh auth login' to authenticate, or"
        Write-Error "  2. Use -GitHubToken parameter or set GITHUB_TOKEN environment variable"
        return $false
    }

    Write-Host "GitHub CLI not authenticated, will use provided token" -ForegroundColor Yellow
    return $true
}

function Invoke-BashTest {
    $scriptPath = Join-Path $PSScriptRoot "test-mcp-workflow.sh"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Bash test script not found at: $scriptPath"
        return $false
    }

    # Convert Windows path to Unix-style path for bash
    $unixPath = $scriptPath -replace '\\', '/' -replace '^([A-Z]):', '/$1'
    
    # Set environment variables for the bash script
    if ($GitHubToken) {
        $env:GITHUB_TOKEN = $GitHubToken
    }
    $env:REPO_OWNER = $RepoOwner
    $env:REPO_NAME = $RepoName

    Write-Host "Starting MCP workflow test..." -ForegroundColor Blue
    Write-Host "Repository: $RepoOwner/$RepoName" -ForegroundColor Blue
    
    # Show authentication method being used
    try {
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Authentication: Using existing GitHub CLI login" -ForegroundColor Blue
        }
    }
    catch {
        if ($GitHubToken) {
            $maskedToken = '*' * 8 + $GitHubToken.Substring([Math]::Max(0, $GitHubToken.Length - 4))
            Write-Host "Authentication: Using provided token ($maskedToken)" -ForegroundColor Blue
        }
    }
    
    Write-Host ""

    try {
        # Execute the bash script
        bash $unixPath
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "`n✅ Test completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "`n❌ Test failed with exit code: $exitCode" -ForegroundColor Red
        }
        
        return ($exitCode -eq 0)
    }
    catch {
        Write-Error "Failed to execute bash script: $_"
        return $false
    }
}

# Function to check if a workflow run is for our specific issue
function Check-OurWorkflow {
    param([string]$IssueNumber)
    
    Write-Host "🔍 Looking for workflow runs triggered by issue #$IssueNumber..." -ForegroundColor Cyan
    
    # Get recent workflow runs for issues-mcp.yml
    try {
        $workflowRuns = gh run list --repo "$RepoOwner/$RepoName" --workflow="issues-mcp.yml" --limit=5 --json databaseId,status,conclusion,event,createdAt | ConvertFrom-Json
        
        if (-not $workflowRuns -or $workflowRuns.Count -eq 0) {
            Write-Host "ℹ️  No workflow runs found for issues-mcp.yml" -ForegroundColor Yellow
            return 1
        }
        
        foreach ($run in $workflowRuns) {
            if ($run.databaseId) {
                # Get detailed run info
                try {
                    $runInfo = gh run view $run.databaseId --repo "$RepoOwner/$RepoName" --json event,status,conclusion,createdAt | ConvertFrom-Json
                    
                    if ($runInfo.event -eq "issues") {
                        # Check if this run is recent (within last 10 minutes)
                        $runTime = [DateTime]::Parse($runInfo.createdAt)
                        $currentTime = Get-Date
                        $timeDiff = ($currentTime - $runTime).TotalSeconds
                        
                        if ($timeDiff -lt 600) {
                            Write-Host "🎯 Found recent issues-triggered workflow run #$($run.databaseId) ($([math]::Round($timeDiff))s ago)" -ForegroundColor Green
                            Write-Host "   Status: $($runInfo.status), Conclusion: $($runInfo.conclusion)" -ForegroundColor Gray
                            
                            switch ($runInfo.status) {
                                { $_ -in @("in_progress", "queued") } {
                                    Write-Host "⏳ Our workflow is currently $($runInfo.status)" -ForegroundColor Yellow
                                    return 0
                                }
                                "completed" {
                                    switch ($runInfo.conclusion) {
                                        "success" {
                                            Write-Host "✅ Our workflow completed successfully!" -ForegroundColor Green
                                            return 0
                                        }
                                        { $_ -in @("failure", "cancelled", "timed_out") } {
                                            Write-Host "❌ Our workflow failed with: $($runInfo.conclusion)" -ForegroundColor Red
                                            
                                            # Get failure details
                                            Write-Host ""
                                            Write-Host "📋 Workflow failure details:" -ForegroundColor Red
                                            try {
                                                $details = gh run view $run.databaseId --repo "$RepoOwner/$RepoName"
                                                $details[0..14] | ForEach-Object { Write-Host $_ }
                                                
                                                Write-Host ""
                                                Write-Host "📝 Recent logs:" -ForegroundColor Red
                                                $logs = gh run view $run.databaseId --repo "$RepoOwner/$RepoName" --log
                                                $logs[-30..-1] | ForEach-Object { Write-Host $_ }
                                            } catch {
                                                Write-Host "Could not retrieve failure details" -ForegroundColor Yellow
                                            }
                                            
                                            return 2
                                        }
                                    }
                                }
                            }
                        } else {
                            Write-Host "ℹ️  Found older issues-triggered run #$($run.databaseId) ($([math]::Round($timeDiff))s ago) - likely not ours" -ForegroundColor Gray
                        }
                    }
                } catch {
                    Write-Host "⚠️  Could not get details for run #$($run.databaseId)" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host "ℹ️  No recent workflow runs found for our issue" -ForegroundColor Yellow
        return 1
        
    } catch {
        Write-Host "❌ Error checking workflow runs: $_" -ForegroundColor Red
        return 1
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

if (-not (Test-Prerequisites)) {
    exit 1
}

$success = Invoke-BashTest

if ($success) {
    Write-Host "`nMCP workflow test completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nMCP workflow test failed!" -ForegroundColor Red
    exit 1
} 