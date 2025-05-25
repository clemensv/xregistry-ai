# A2A (Agent-to-Agent) Workflow Tests

This directory contains test files and scripts for validating the A2A (Agent-to-Agent) GitHub Actions workflow.

## Overview

The A2A workflow (`issues-a2a.yml`) automatically processes GitHub issues that contain YAML configuration pointing to agent.json files. When an issue is created with the proper format, the workflow:

1. Extracts YAML configuration from the issue body
2. Fetches the agent.json file from the specified repository and path
3. Validates the agent.json content
4. Creates a registry entry at `registry/agentcardproviders/{provider}/agentcards/{agentcard}/index.json`
5. Commits and pushes the registry entry
6. Comments on the issue with success/failure status
7. Closes the issue if successful

## Files in this Directory

### Core Test Files
- **`agent.json`** - Sample agent configuration file for testing
- **`simple-test.sh`** - Basic test script that creates an issue and monitors the workflow
- **`test-issue-body.md`** - Template issue body with proper YAML formatting

### Test Scripts
- **`simple-test.sh`** - Streamlined test for quick validation

## Expected YAML Format

Issues should contain YAML blocks in this format:

```yaml
repo: owner/repository-name
path: path/to/agent/files
branch: main
agentcardprovider: provider-name
agentcard: agentcard-name
```

### Parameters

- **`repo`**: Repository containing the agent.json file (format: "owner/repo" or full GitHub URL)
- **`path`**: Directory path within the repository where agent.json is located
- **`branch`**: Git branch to fetch from (default: "main")
- **`agentcardprovider`**: Provider name for the registry path
- **`agentcard`**: Agent card name for the registry path

## Workflow Parameters

The A2A workflow calls the validation script with these parameters:
```bash
node .github/scripts/validate-submission.js \
  --gs agentcardprovider \
  --gp agentcardproviders \
  --rs agentcard \
  --rp agentcards \
  --f agent.json \
  --d
```

Key differences from MCP workflow:
- Uses `agentcardprovider`/`agentcardproviders` instead of `mcpprovider`/`mcpproviders`
- Uses `agentcard`/`agentcards` instead of `server`/`servers`
- Looks for `agent.json` instead of `mcp.json`
- Uses the `-d` (document) flag for composite registry entries

## Registry Structure

Successful submissions create entries at:
```
registry/agentcardproviders/{provider}/agentcards/{agentcard}/index.json
```

The registry entry contains both the agent configuration and metadata:
```json
{
  "agentcardid": "agentcard-name",
  "agentcard": {
    // Original agent.json content
  }
}
```

## Running Tests

### Prerequisites
1. GitHub CLI installed and authenticated (`gh auth login`)
2. Access to the target repository
3. Bash shell environment

### Basic Test
```bash
# Run the simple test
./test/a2a/simple-test.sh
```

The test will:
1. Verify GitHub CLI authentication
2. Create a test issue with YAML pointing to `test/a2a/agent.json`
3. Monitor the workflow execution
4. Validate registry entry creation
5. Report success/failure

### Manual Testing
You can also create issues manually with YAML content:

```markdown
Testing A2A workflow

\`\`\`yaml
repo: clemensv/xregistry-ai
path: test/a2a
branch: main
agentcardprovider: my-test-provider
agentcard: my-test-agentcard
\`\`\`
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Ensure GitHub CLI is authenticated with proper permissions
2. **File Not Found**: Verify the agent.json file exists at the specified path
3. **Invalid YAML**: Check YAML formatting and required fields
4. **Registry Conflicts**: Existing registry entries will cause failures

### Workflow Monitoring

The test scripts include workflow monitoring that:
- Tracks specific workflow runs triggered by your issues
- Provides real-time status updates
- Shows detailed error information for failures
- Displays workflow logs for debugging

### Example Output

```
=== Simple A2A Workflow Test ===
Repository: clemensv/xregistry-ai
Test Provider: test-provider
Test Agent Card: test-agentcard

✅ Authenticated as: username
✅ Created issue #123
Issue URL: https://github.com/clemensv/xregistry-ai/issues/123

🔍 Looking for workflow runs triggered by issue #123...
🎯 Found recent issues-triggered workflow run #456789
   Status: success
✅ Our workflow completed successfully!

=== Test Summary ===
✅ Registry entry created successfully
✅ Issue closed successfully
🎉 A2A workflow test completed successfully!
```

## Agent.json Schema

The agent.json file should follow the A2A schema with these key elements:

```json
{
  "name": "Agent Name",
  "description": "Agent description",
  "url": "https://agent.example.com/a2a",
  "version": "1.0.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": false,
    "stateTransitionHistory": true
  },
  "authentication": {
    "schemes": ["apiKey"]
  },
  "defaultInputModes": ["text"],
  "defaultOutputModes": ["text"],
  "skills": [
    {
      "id": "skill_id",
      "name": "Skill Name",
      "description": "Skill description",
      "inputModes": ["text"],
      "outputModes": ["text"],
      "examples": ["Example usage"]
    }
  ]
}
```

## Cleanup

Test registry entries can be cleaned up manually:
```bash
rm -rf registry/agentcardproviders/test-provider
git add . && git commit -m "Clean up A2A test entries" && git push
``` 