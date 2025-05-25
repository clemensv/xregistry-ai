#!/bin/bash

# Simple test script for MCP workflow validation
set -e

# Configuration
REPO_OWNER="clemensv"
REPO_NAME="xregistry-ai"
ISSUE_TITLE="Simple MCP Test - $(date +%Y%m%d%H%M%S)"
TEST_PROVIDER="test-provider"
TEST_SERVER="test-server"

echo "=== Simple MCP Workflow Test ==="
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Test Provider: $TEST_PROVIDER"
echo "Test Server: $TEST_SERVER"
echo ""

# Check if GitHub CLI is authenticated
echo "Checking GitHub authentication..."
if gh auth status &> /dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    echo "✅ Authenticated as: $GH_USER"
else
    echo "❌ Not authenticated. Please run: gh auth login"
    exit 1
fi

# Function to check if a workflow run is for our specific issue
check_our_workflow() {
    local issue_number=$1
    
    echo "🔍 Looking for workflow runs triggered by issue #$issue_number..."
    
    # Get recent workflow runs for issues-mcp.yml
    local workflow_runs=$(gh run list --repo "$REPO_OWNER/$REPO_NAME" --workflow="issues-mcp.yml" --limit=5 --json databaseId,status,conclusion,event,createdAt 2>/dev/null)
    
    if [ -z "$workflow_runs" ] || [ "$workflow_runs" = "[]" ]; then
        echo "ℹ️  No workflow runs found for issues-mcp.yml"
        return 1
    fi
    
    # Extract run IDs and check each one
    local run_ids=$(echo "$workflow_runs" | grep -o '"databaseId":[0-9]*' | cut -d':' -f2)
    
    for run_id in $run_ids; do
        if [ -n "$run_id" ]; then
            # Get run details
            local run_info=$(gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --json event,status,conclusion,createdAt 2>/dev/null)
            
            if [ -n "$run_info" ]; then
                local event=$(echo "$run_info" | grep -o '"event":"[^"]*"' | cut -d'"' -f4)
                local status=$(echo "$run_info" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
                local conclusion=$(echo "$run_info" | grep -o '"conclusion":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "null")
                local created_at=$(echo "$run_info" | grep -o '"createdAt":"[^"]*"' | cut -d'"' -f4)
                
                if [ "$event" = "issues" ]; then
                    # Check if this run is recent (within last 10 minutes)
                    local run_time=$(date -d "$created_at" +%s 2>/dev/null || echo "0")
                    local current_time=$(date +%s)
                    local time_diff=$((current_time - run_time))
                    
                    if [ $time_diff -lt 600 ]; then
                        echo "🎯 Found recent issues-triggered workflow run #$run_id (${time_diff}s ago)"
                        echo "   Status: $status, Conclusion: $conclusion"
                        
                        case "$status" in
                            "in_progress"|"queued")
                                echo "⏳ Our workflow is currently $status"
                                return 0
                                ;;
                            "completed")
                                case "$conclusion" in
                                    "success")
                                        echo "✅ Our workflow completed successfully!"
                                        return 0
                                        ;;
                                    "failure"|"cancelled"|"timed_out")
                                        echo "❌ Our workflow failed with: $conclusion"
                                        
                                        # Get failure details
                                        echo ""
                                        echo "📋 Workflow failure details:"
                                        gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" 2>/dev/null | head -15 || echo "Could not get details"
                                        echo ""
                                        echo "📝 Recent logs:"
                                        gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --log 2>/dev/null | tail -30 || echo "Could not get logs"
                                        
                                        return 2
                                        ;;
                                esac
                                ;;
                        esac
                    else
                        echo "ℹ️  Found older issues-triggered run #$run_id (${time_diff}s ago) - likely not ours"
                    fi
                fi
            fi
        fi
    done
    
    echo "ℹ️  No recent workflow runs found for our issue"
    return 1
}

# Create test issue
echo ""
echo "Creating test issue..."

ISSUE_BODY='This is a simple test submission for the MCP workflow validation.

```yaml
repo: clemensv/xregistry-ai
path: test/mcp
branch: main
mcpprovider: '"$TEST_PROVIDER"'
server: '"$TEST_SERVER"'
```

This issue will be automatically processed by the GitHub Actions workflow.'

ISSUE_URL=$(gh issue create \
    --repo "$REPO_OWNER/$REPO_NAME" \
    --title "$ISSUE_TITLE" \
    --body "$ISSUE_BODY")

ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

if [ -z "$ISSUE_NUMBER" ]; then
    echo "❌ Failed to create issue"
    exit 1
fi

echo "✅ Created issue #$ISSUE_NUMBER"
echo "Issue URL: $ISSUE_URL"

# Simple wait with basic monitoring
echo ""
echo "Waiting for workflow to complete (checking every 30 seconds for up to 5 minutes)..."

max_wait=300
wait_time=0
check_interval=30

while [ $wait_time -lt $max_wait ]; do
    echo ""
    echo "--- Check at $wait_time seconds ---"
    
    # Check issue state
    ISSUE_STATE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state' 2>/dev/null)
    echo "Issue #$ISSUE_NUMBER state: $ISSUE_STATE"
    
    if [ "$ISSUE_STATE" = "CLOSED" ]; then
        echo "✅ Issue has been closed by workflow!"
        break
    fi
    
    # Check if registry entry exists
    expected_path="registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
    if [ -f "$expected_path" ]; then
        echo "✅ Registry entry found at: $expected_path"
        break
    else
        echo "⏳ Registry entry not yet created at: $expected_path"
    fi
    
    # Check our specific workflow
    echo ""
    check_our_workflow "$ISSUE_NUMBER"
    workflow_result=$?
    
    case $workflow_result in
        0)
            echo "✅ Workflow is running or completed successfully"
            ;;
        2)
            echo ""
            echo "❌ TEST FAILED: Our workflow execution failed"
            
            # Close the issue and exit
            if [ "$ISSUE_STATE" != "CLOSED" ]; then
                echo "Closing test issue..."
                gh issue close "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --comment "Test failed due to workflow failure"
            fi
            
            exit 1
            ;;
        1)
            echo "ℹ️  No definitive workflow status yet"
            ;;
    esac
    
    if [ $wait_time -lt $max_wait ]; then
        echo "Waiting $check_interval more seconds..."
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    fi
done

echo ""
echo "=== Final Status Check ==="

# Final checks
ISSUE_STATE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state' 2>/dev/null)
echo "Final issue state: $ISSUE_STATE"

expected_path="registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
if [ -f "$expected_path" ]; then
    echo "✅ Registry entry created successfully!"
    echo "Contents:"
    cat "$expected_path"
    
    # Cleanup
    echo ""
    echo "Cleaning up registry entry..."
    rm -rf "registry/mcpproviders/$TEST_PROVIDER"
    echo "✅ Cleaned up"
else
    echo "❌ Registry entry not found"
fi

# Close issue if still open
if [ "$ISSUE_STATE" != "CLOSED" ]; then
    echo ""
    echo "Closing test issue..."
    gh issue close "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --comment "Simple test completed"
    echo "✅ Issue closed"
fi

echo ""
echo "=== Test Complete ===" 