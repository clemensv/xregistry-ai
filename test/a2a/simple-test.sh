#!/bin/bash

# Simple A2A Workflow Test
# Tests the GitHub Actions workflow for A2A agent ingestion

set -e

# Configuration
REPO_OWNER="clemensv"
REPO_NAME="xregistry-ai"
TEST_PROVIDER="test-provider"
TEST_AGENTCARD="test-agentcard"

echo "=== Simple A2A Workflow Test ==="
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Test Provider: $TEST_PROVIDER"
echo "Test Agent Card: $TEST_AGENTCARD"
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
echo ""

# Function to check if a workflow run is for our specific issue
check_our_workflow() {
    local issue_number=$1
    
    echo "🔍 Looking for workflow runs triggered by issue #$issue_number..."
    
    # Get recent workflow runs for issues-a2a.yml
    local workflow_runs=$(gh run list --repo "$REPO_OWNER/$REPO_NAME" --workflow="issues-a2a.yml" --limit=5 --json databaseId,status,conclusion,event,createdAt 2>/dev/null)
    
    if [ -z "$workflow_runs" ] || [ "$workflow_runs" = "[]" ]; then
        echo "ℹ️  No workflow runs found for issues-a2a.yml"
        return 1
    fi
    
    # Parse JSON manually (fallback if jq not available)
    local recent_runs=$(echo "$workflow_runs" | grep -o '"databaseId":[0-9]*' | head -3)
    
    for run_line in $recent_runs; do
        local run_id=$(echo "$run_line" | grep -o '[0-9]*')
        if [ -n "$run_id" ]; then
            # Get workflow run details
            local run_details=$(gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" 2>/dev/null || echo "")
            if echo "$run_details" | grep -q "issues.*$(date +%Y-%m-%d)" || echo "$run_details" | grep -q "less than.*minute"; then
                local status=$(echo "$run_details" | grep -o "✓\|X\|*" | head -1)
                local status_text="unknown"
                case "$status" in
                    "✓") status_text="success" ;;
                    "X") status_text="failure" ;;
                    "*") status_text="in_progress" ;;
                esac
                
                echo "🎯 Found recent issues-triggered workflow run #$run_id"
                echo "   Status: $status_text"
                
                if [ "$status_text" = "success" ]; then
                    echo "✅ Our workflow completed successfully!"
                    return 0
                elif [ "$status_text" = "failure" ]; then
                    echo "❌ Our workflow failed with: $status_text"
                    echo ""
                    echo "📋 Workflow failure details:"
                    echo ""
                    gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" 2>/dev/null || echo "Could not fetch details"
                    echo ""
                    echo "📝 Recent logs:"
                    gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --log 2>/dev/null | tail -20 || echo "Could not fetch logs"
                    return 1
                elif [ "$status_text" = "in_progress" ]; then
                    echo "⏳ Our workflow is still running..."
                    return 2
                fi
            fi
        fi
    done
    
    echo "ℹ️  No recent workflow runs found for this issue"
    return 1
}

# Create test issue with YAML content
echo "Creating test issue..."
ISSUE_TITLE="Simple A2A Test - $(date +%Y%m%d%H%M%S)"

ISSUE_BODY="This is a simple test submission for the A2A workflow validation.

\`\`\`yaml
repo: $REPO_OWNER/$REPO_NAME
path: test/a2a
branch: main
agentcardprovider: $TEST_PROVIDER
agentcard: $TEST_AGENTCARD
\`\`\`

This issue will be automatically processed by the GitHub Actions workflow."

# Create the issue and capture the issue number
ISSUE_URL=$(gh issue create --repo "$REPO_OWNER/$REPO_NAME" --title "$ISSUE_TITLE" --body "$ISSUE_BODY")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

echo "✅ Created issue #$ISSUE_NUMBER"
echo "Issue URL: $ISSUE_URL"
echo ""

# Wait for workflow to complete
echo "Waiting for workflow to complete (checking every 30 seconds for up to 5 minutes)..."
echo ""

max_wait=300  # 5 minutes
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
    expected_path="registry/agentcardproviders/$TEST_PROVIDER/agentcards/$TEST_AGENTCARD/index.json"
    if [ -f "$expected_path" ]; then
        echo "✅ Registry entry found at: $expected_path"
        break
    else
        echo "⏳ Registry entry not yet created at: $expected_path"
    fi
    
    # Check our specific workflow
    check_result=$(check_our_workflow "$ISSUE_NUMBER")
    workflow_status=$?
    
    if [ $workflow_status -eq 0 ]; then
        echo "✅ Workflow is running or completed successfully"
        break
    elif [ $workflow_status -eq 1 ]; then
        echo "❌ Workflow failed"
        exit 1
    else
        echo "✅ Workflow is running or completed successfully"
    fi
    
    if [ $wait_time -ge $max_wait ]; then
        break
    fi
    
    echo "Waiting $check_interval more seconds..."
    sleep $check_interval
    wait_time=$((wait_time + check_interval))
done

echo ""
echo "=== Test Summary ==="

# Final check
if [ -f "$expected_path" ]; then
    echo "✅ Registry entry created successfully"
    echo "📄 Content preview:"
    head -10 "$expected_path"
    echo ""
else
    echo "❌ Registry entry not found"
    exit 1
fi

if [ "$ISSUE_STATE" = "CLOSED" ]; then
    echo "✅ Issue closed successfully"
else
    echo "⚠️  Issue still open: $ISSUE_URL"
fi

echo ""
echo "🎉 A2A workflow test completed successfully!"
echo "📍 Registry entry: $expected_path"
echo "�� Issue: $ISSUE_URL" 