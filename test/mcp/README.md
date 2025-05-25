# MCP Workflow Test

This directory contains test files for validating the MCP (Model Context Protocol) submission workflow via GitHub Issues.

## Files

- `mcp.json` - A fictional MCP server definition used for testing
- `test-mcp-workflow.sh` - Bash script that tests the complete workflow
- `test-mcp-workflow.ps1` - PowerShell wrapper for the bash script
- `verify-setup.sh` - Verification script to check prerequisites
- `README.md` - This documentation file

## Test Overview

The test script validates the following workflow:

1. **Issue Creation**: Creates a GitHub issue with the required YAML format
2. **Workflow Trigger**: The `issues-mcp.yml` GitHub Actions workflow is triggered
3. **Processing**: The workflow processes the issue and creates registry entries
4. **Validation**: The script checks if the entry was created successfully
5. **Cleanup**: Removes the test entry and closes the issue

## Prerequisites

1. **GitHub CLI**: Install from https://cli.github.com/
2. **GitHub Authentication**: Either:
   - Be logged in with `gh auth login`, or
   - Have a GitHub personal access token with repo permissions
3. **Bash Environment**: The script requires bash (available in Git Bash on Windows)

## Quick Start

1. **Verify Setup** (recommended):
   ```bash
   ./test/mcp/verify-setup.sh
   ```

2. **Authenticate with GitHub** (if not already done):
   ```bash
   # Option 1: Use GitHub CLI login (recommended)
   gh auth login
   
   # Option 2: Set token (if you prefer)
   export GITHUB_TOKEN=your_personal_access_token_here
   ```

3. **Run the test**:
   ```bash
   # Using bash script
   ./test/mcp/test-mcp-workflow.sh
   
   # Or using PowerShell
   .\test\mcp\test-mcp-workflow.ps1
   ```

## Usage Options

### Bash Script
```bash
./test/mcp/test-mcp-workflow.sh
```

### PowerShell Script
```powershell
# Basic usage
.\test\mcp\test-mcp-workflow.ps1

# With parameters
.\test\mcp\test-mcp-workflow.ps1 -GitHubToken "ghp_xxxxxxxxxxxx"

# Help
.\test\mcp\test-mcp-workflow.ps1 -Help
```

### Verification Script
```bash
# Check if everything is set up correctly
./test/mcp/verify-setup.sh
```

The verification script checks:
- Required files exist
- JSON validity of mcp.json
- GitHub CLI availability
- Script permissions
- Git configuration
- GitHub token presence

## Test Process

The script will:
- Create a test issue with the required YAML content
- Wait for the GitHub Actions workflow to process it (up to 5 minutes)
- Check if the registry entry was created
- Display the results
- Clean up the test entry and issue

## Expected Behavior

### Success Case
- Issue is created successfully
- GitHub Actions workflow processes the issue
- Registry entry is created at `registry/mcpproviders/test-provider/servers/test-server/index.json`
- Issue is closed with a success comment (✅)
- Test entry is cleaned up
- Test reports success

### Failure Cases
- Missing GitHub token
- GitHub CLI not installed
- Workflow timeout (> 5 minutes)
- Registry entry not created
- Error comments in the issue (❌)

## Test Configuration

The test uses these default values (configurable in the script):

- **Repository**: `clemensv/xregistry-ai`
- **Test Provider**: `test-provider`
- **Test Server**: `test-server`
- **MCP File**: Points to `test/mcp/mcp.json` in this repo
- **Timeout**: 5 minutes maximum wait time

## Troubleshooting

### GitHub Authentication Issues
The script supports two authentication methods:

**Option 1: GitHub CLI Login (Recommended)**
```bash
gh auth login
# Follow the prompts to authenticate
```

**Option 2: Personal Access Token**
```bash
export GITHUB_TOKEN=your_token_here
```

**Check Authentication Status**
```bash
gh auth status
```

### Workflow Not Triggering
- Check if the issue was created with the correct YAML format
- Verify the workflow file `.github/workflows/issues-mcp.yml` exists
- Check GitHub Actions tab for workflow runs

### Permission Issues
- Ensure your GitHub authentication has `repo` permissions
- Check if you have write access to the repository

### Script Permission Issues
```bash
chmod +x test/mcp/test-mcp-workflow.sh
chmod +x test/mcp/verify-setup.sh
```

## Manual Testing

You can also manually test by creating an issue with this content:

```yaml
repo: clemensv/xregistry-ai
path: test/mcp
branch: main
mcpprovider: test-provider
server: test-server
```

## Cleanup

The script automatically cleans up after itself, but if you need to manually clean up:

1. Remove the registry entry:
   ```bash
   rm -rf registry/mcpproviders/test-provider
   ```

2. Close any test issues via the GitHub web interface

## Contributing

If you modify this test:

1. Test your changes thoroughly
2. Update this README if needed
3. Ensure the test cleans up properly
4. Consider adding additional test cases
5. Run the verification script to ensure setup is correct

## Enhanced Workflow Monitoring

### Issue-Specific Tracking

The test scripts now include enhanced monitoring that can specifically tell if a workflow run is processing our particular issue:

#### How It Works

1. **Issue Creation Tracking**: When we create an issue, we capture the issue number
2. **Workflow Event Filtering**: We query GitHub for workflow runs triggered by "issues" events
3. **Timestamp Correlation**: We check if workflow runs were created recently (within 10 minutes of our issue)
4. **Event Type Verification**: We verify the workflow was triggered by an issues event, not push/PR/etc.

#### What You'll See

```bash
🔍 Looking for workflow runs triggered by issue #123...
🎯 Found recent issues-triggered workflow run #456789 (45s ago)
   Status: in_progress, Conclusion: null
⏳ Our workflow is currently in_progress
```

Or if there's a failure:
```bash
🔍 Looking for workflow runs triggered by issue #123...
🎯 Found recent issues-triggered workflow run #456789 (120s ago)
   Status: completed, Conclusion: failure
❌ Our workflow failed with: failure

📋 Workflow failure details:
[Detailed workflow information]

📝 Recent logs:
[Last 30 lines of workflow logs]
```

#### Benefits

- **Precise Tracking**: Know exactly if YOUR issue is being processed
- **Immediate Failure Detection**: Stop waiting as soon as YOUR workflow fails
- **Relevant Debugging**: Get logs and details for YOUR specific run
- **Avoid False Positives**: Don't get confused by other workflows running

#### Functions Added

- `find_issue_workflow_runs()` - Searches for workflow runs triggered by our specific issue
- `check_our_workflow()` - Enhanced monitoring with issue correlation
- `Check-OurWorkflow` - PowerShell equivalent

#### Fallback Behavior

If we can't definitively identify our specific workflow run, the scripts fall back to general workflow monitoring to ensure we don't miss anything.

## Scripts Overview 