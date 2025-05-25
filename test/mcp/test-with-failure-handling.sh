#!/bin/bash

# Comprehensive MCP workflow test with failure handling
set -e

# Configuration
REPO_OWNER="clemensv"
REPO_NAME="xregistry-ai"
ISSUE_TITLE="MCP Test with Failure Handling - $(date +%Y%m%d%H%M%S)"
TEST_PROVIDER="test-provider"
TEST_SERVER="test-server"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== MCP Workflow Test with Failure Handling ==="
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Test Provider: $TEST_PROVIDER"
echo "Test Server: $TEST_SERVER"
echo ""

# Check authentication
if gh auth status &> /dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    print_success "Authenticated as: $GH_USER"
else
    print_error "Not authenticated. Please run: gh auth login"
    exit 1
fi

# Create test issue
print_status "Creating test issue..."

ISSUE_BODY='This is a test for the MCP workflow with failure handling.

```yaml
repo: clemensv/xregistry-ai
path: test/mcp
branch: main
mcpprovider: '"$TEST_PROVIDER"'
server: '"$TEST_SERVER"'
```

This issue will be processed by the GitHub Actions workflow.'

ISSUE_URL=$(gh issue create --repo "$REPO_OWNER/$REPO_NAME" --title "$ISSUE_TITLE" --body "$ISSUE_BODY")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

if [ -z "$ISSUE_NUMBER" ]; then
    print_error "Failed to create issue"
    exit 1
fi

print_success "Created issue #$ISSUE_NUMBER"
echo "URL: $ISSUE_URL"

# Monitor workflow with detailed failure handling
print_status "Monitoring workflow execution..."

max_wait=300
wait_time=0
check_interval=20

while [ $wait_time -lt $max_wait ]; do
    echo ""
    print_status "Check at $wait_time seconds..."
    
    # Check issue state
    ISSUE_STATE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state' 2>/dev/null || echo "unknown")
    print_status "Issue state: $ISSUE_STATE"
    
    if [ "$ISSUE_STATE" = "CLOSED" ]; then
        print_success "Issue closed by workflow!"
        break
    fi
    
    # Check registry entry
    expected_path="registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
    if [ -f "$expected_path" ]; then
        print_success "Registry entry found!"
        break
    fi
    
    # Check workflows
    print_status "Checking workflow runs..."
    workflow_list=$(gh run list --repo "$REPO_OWNER/$REPO_NAME" --limit=3 2>/dev/null || echo "error")
    
    if [ "$workflow_list" != "error" ]; then
        echo "$workflow_list" | head -4
        
        # Check for failures
        if echo "$workflow_list" | grep -q "failure"; then
            print_error "WORKFLOW FAILURE DETECTED!"
            
            # Get details of the failed run
            failed_run_line=$(echo "$workflow_list" | grep "failure" | head -1)
            failed_run_id=$(echo "$failed_run_line" | awk '{print $NF}')
            
            if [ -n "$failed_run_id" ]; then
                echo ""
                print_error "Failed Run Details:"
                gh run view "$failed_run_id" --repo "$REPO_OWNER/$REPO_NAME" 2>/dev/null | head -20 || print_warning "Could not get run details"
                
                echo ""
                print_error "Failure Logs (last 50 lines):"
                gh run view "$failed_run_id" --repo "$REPO_OWNER/$REPO_NAME" --log 2>/dev/null | tail -50 || print_warning "Could not get logs"
            fi
            
            # Close issue and exit
            print_status "Closing test issue due to workflow failure..."
            gh issue close "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --comment "Test failed: Workflow execution failed. See logs above." 2>/dev/null || true
            
            echo ""
            print_error "❌ TEST FAILED: Workflow execution failed"
            print_error "Check the logs above for failure details"
            exit 1
        fi
        
        # Check for in-progress workflows
        if echo "$workflow_list" | grep -q "in_progress\|queued"; then
            print_status "Workflow is running..."
        fi
    else
        print_warning "Could not fetch workflow status"
    fi
    
    if [ $wait_time -lt $max_wait ]; then
        print_status "Waiting $check_interval more seconds..."
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    fi
done

# Final status check
echo ""
print_status "=== Final Status Check ==="

ISSUE_STATE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state' 2>/dev/null || echo "unknown")
print_status "Final issue state: $ISSUE_STATE"

expected_path="registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
if [ -f "$expected_path" ]; then
    print_success "✅ TEST PASSED: Registry entry created!"
    echo ""
    echo "Entry contents:"
    cat "$expected_path"
    
    # Cleanup
    echo ""
    print_status "Cleaning up test entry..."
    rm -rf "registry/mcpproviders/$TEST_PROVIDER"
    print_success "Cleaned up"
else
    print_error "❌ Registry entry not found"
    
    # Get final workflow status
    print_status "Checking final workflow status for debugging..."
    gh run list --repo "$REPO_OWNER/$REPO_NAME" --limit=5 2>/dev/null | head -6 || print_warning "Could not get workflow status"
fi

# Close issue if still open
if [ "$ISSUE_STATE" != "CLOSED" ]; then
    print_status "Closing test issue..."
    gh issue close "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --comment "Test completed" 2>/dev/null || true
fi

echo ""
if [ -f "$expected_path" ] || [ -d "registry/mcpproviders/$TEST_PROVIDER" ]; then
    print_success "=== TEST COMPLETED SUCCESSFULLY ==="
else
    print_error "=== TEST FAILED ==="
    exit 1
fi 