#!/bin/bash

# Test script for MCP workflow validation
# This script tests the issues-mcp.yml GitHub Actions workflow

set -e

# Configuration
REPO_OWNER="clemensv"
REPO_NAME="xregistry-ai"
ISSUE_TITLE="Test MCP Submission - $(date +%Y%m%d%H%M%S)"
TEST_PROVIDER="test-provider"
TEST_SERVER="test-server"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
    
# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if GitHub CLI is available and authenticated
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_error "Please install it from https://cli.github.com/"
        exit 1
    fi
    
    # Check if already authenticated
    if gh auth status &> /dev/null; then
        print_success "GitHub CLI is already authenticated"
        # Get the authenticated user info
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
        print_status "Authenticated as: $GH_USER"
        return 0
    fi
    
    # If not authenticated, try to use GITHUB_TOKEN if provided
    if [ -n "$GITHUB_TOKEN" ]; then
        print_status "GitHub CLI not authenticated, using GITHUB_TOKEN..."
        echo "$GITHUB_TOKEN" | gh auth login --with-token
        print_success "GitHub CLI authenticated with token"
        return 0
    fi
    
    # Neither authenticated nor token provided
    print_error "GitHub CLI is not authenticated and no GITHUB_TOKEN provided"
    print_error "Please either:"
    print_error "  1. Run 'gh auth login' to authenticate, or"
    print_error "  2. Set GITHUB_TOKEN environment variable"
    exit 1
}

# Function to create test issue
create_issue() {
    print_status "Creating test issue..." >&2
    
    # YAML content for the issue
    ISSUE_BODY='This is a test submission for the MCP workflow validation.

```yaml
repo: clemensv/xregistry-ai
path: test/mcp
branch: main
mcpprovider: '"$TEST_PROVIDER"'
server: '"$TEST_SERVER"'
```

This issue will be automatically processed by the GitHub Actions workflow.'

    # Create the issue
    ISSUE_URL=$(gh issue create \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --title "$ISSUE_TITLE" \
        --body "$ISSUE_BODY")
    
    # Extract issue number from URL (e.g., https://github.com/clemensv/xregistry-ai/issues/5 -> 5)
    ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
    
    if [ -z "$ISSUE_NUMBER" ]; then
        print_error "Failed to create issue or extract issue number from: $ISSUE_URL" >&2
        exit 1
    fi
    
    # Try to add label if it exists (optional)
    if gh label list --repo "$REPO_OWNER/$REPO_NAME" | grep -q "mcp-submission"; then
        gh issue edit "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --add-label "mcp-submission" 2>/dev/null || true
        print_status "Added mcp-submission label to issue" >&2
    fi
    
    print_success "Created issue #$ISSUE_NUMBER" >&2
    echo "$ISSUE_NUMBER"
}

# Function to get workflow failure details
get_workflow_failure_details() {
    local workflow_id=$1
    print_status "Getting failure details for workflow run..." >&2
    
    # Get the workflow run details
    local run_details=$(gh run view "$workflow_id" --repo "$REPO_OWNER/$REPO_NAME" 2>/dev/null || echo "")
    
    if [ -n "$run_details" ]; then
        print_error "Workflow Run Details:" >&2
        echo "$run_details" | head -20 >&2
        echo "" >&2
    fi
    
    # Try to get the logs for failed jobs
    print_status "Attempting to get workflow logs..." >&2
    gh run view "$workflow_id" --repo "$REPO_OWNER/$REPO_NAME" --log 2>/dev/null | tail -50 >&2 || {
        print_warning "Could not retrieve workflow logs" >&2
    }
}

# Function to find workflow runs specifically triggered by our issue
find_issue_workflow_runs() {
    local issue_number=$1
    local workflow_name="issues-mcp.yml"
    
    print_status "Looking for workflow runs triggered by issue #$issue_number..." >&2
    
    # Get recent workflow runs for the issues-mcp workflow
    local runs=$(gh run list --repo "$REPO_OWNER/$REPO_NAME" --workflow="$workflow_name" --limit=10 --json databaseId,status,conclusion,event,headSha,createdAt 2>/dev/null)
    
    if [ -z "$runs" ] || [ "$runs" = "[]" ]; then
        print_warning "No workflow runs found for $workflow_name" >&2
        return 1
    fi
    
    # Parse JSON to find runs triggered by issues event
    local issue_runs=""
    local temp_file=$(mktemp)
    echo "$runs" > "$temp_file"
    
    # Extract runs that were triggered by issues event
    # We need to check each run to see if it was triggered by our issue
    local run_ids=$(echo "$runs" | grep -o '"databaseId":[0-9]*' | cut -d':' -f2 | head -5)
    
    local found_our_run=false
    for run_id in $run_ids; do
        if [ -n "$run_id" ]; then
            # Get detailed info for this run to check if it was triggered by our issue
            local run_details=$(gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --json event,headBranch,headSha,status,conclusion,createdAt 2>/dev/null)
            
            if [ -n "$run_details" ]; then
                local event=$(echo "$run_details" | grep -o '"event":"[^"]*"' | cut -d'"' -f4)
                local status=$(echo "$run_details" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
                local conclusion=$(echo "$run_details" | grep -o '"conclusion":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "null")
                local created_at=$(echo "$run_details" | grep -o '"createdAt":"[^"]*"' | cut -d'"' -f4)
                
                if [ "$event" = "issues" ]; then
                    print_status "Found issues-triggered run #$run_id: status=$status, conclusion=$conclusion, created=$created_at" >&2
                    
                    # Check if this run was created recently (within last 10 minutes)
                    # This is a reasonable assumption that it's for our issue
                    local run_time=$(date -d "$created_at" +%s 2>/dev/null || echo "0")
                    local current_time=$(date +%s)
                    local time_diff=$((current_time - run_time))
                    
                    if [ $time_diff -lt 600 ]; then  # Within 10 minutes
                        print_status "Run #$run_id is recent (${time_diff}s ago), likely our issue" >&2
                        found_our_run=true
                        
                        # Return the status
                        case "$status" in
                            "in_progress"|"queued")
                                print_status "Our workflow is $status" >&2
                                rm -f "$temp_file"
                                return 0
                                ;;
                            "completed")
                                case "$conclusion" in
                                    "success")
                                        print_success "Our workflow completed successfully" >&2
                                        rm -f "$temp_file"
                                        return 0
                                        ;;
                                    "failure"|"cancelled"|"timed_out")
                                        print_error "Our workflow failed with conclusion: $conclusion" >&2
                                        get_workflow_failure_details "$run_id"
                                        rm -f "$temp_file"
                                        return 2
                                        ;;
                                    *)
                                        print_warning "Our workflow completed with unknown conclusion: $conclusion" >&2
                                        rm -f "$temp_file"
                                        return 1
                                        ;;
                                esac
                                ;;
                            "failure"|"cancelled"|"timed_out")
                                print_error "Our workflow $status" >&2
                                get_workflow_failure_details "$run_id"
                                rm -f "$temp_file"
                                return 2
                                ;;
                        esac
                    else
                        print_status "Run #$run_id is older (${time_diff}s ago), likely not our issue" >&2
                    fi
                fi
            fi
        fi
    done
    
    rm -f "$temp_file"
    
    if [ "$found_our_run" = "false" ]; then
        print_status "No recent workflow runs found for issue #$issue_number" >&2
        return 1
    fi
    
    return 1
}

# Function to check workflow run status (enhanced to track specific issue)
check_workflow_runs() {
    local issue_number=$1
    
    # First try to find workflow runs specifically for our issue
    find_issue_workflow_runs "$issue_number"
    local result=$?
    
    if [ $result -ne 1 ]; then
        # Found a definitive status (success, failure, or in-progress)
        return $result
    fi
    
    # Fallback to general workflow check if no specific run found
    local workflow_name="issues-mcp.yml"
    print_status "Fallback: Checking general workflow runs for $workflow_name..." >&2
    
    local runs=$(gh run list --repo "$REPO_OWNER/$REPO_NAME" --workflow="$workflow_name" --limit=3 2>/dev/null)
    
    if [ -z "$runs" ]; then
        print_warning "No workflow runs found for $workflow_name" >&2
        return 1
    fi
    
    # Parse workflow runs line by line
    local temp_file=$(mktemp)
    echo "$runs" | tail -n +2 | head -3 > "$temp_file"
    
    local found_status=1
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local status=$(echo "$line" | awk '{print $2}')
            local workflow_id=$(echo "$line" | awk '{print $NF}')
            
            print_status "General workflow status: $status (ID: $workflow_id)" >&2
            
            case "$status" in
                "in_progress"|"queued")
                    print_status "A workflow is $status (may be ours)" >&2
                    found_status=0
                    break
                    ;;
                "completed")
                    local run_conclusion=$(gh run view "$workflow_id" --repo "$REPO_OWNER/$REPO_NAME" --json conclusion --jq '.conclusion' 2>/dev/null || echo "unknown")
                    print_status "A workflow completed with conclusion: $run_conclusion" >&2
                    
                    case "$run_conclusion" in
                        "success")
                            print_success "A workflow completed successfully (may be ours)" >&2
                            found_status=0
                            break
                            ;;
                        "failure"|"cancelled"|"timed_out")
                            print_error "A workflow failed with conclusion: $run_conclusion (may be ours)" >&2
                            get_workflow_failure_details "$workflow_id"
                            found_status=2
                            break
                            ;;
                    esac
                    ;;
                "failure"|"cancelled"|"timed_out")
                    print_error "A workflow $status (may be ours)" >&2
                    get_workflow_failure_details "$workflow_id"
                    found_status=2
                    break
                    ;;
            esac
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ $found_status -eq 1 ]; then
        print_status "No recent workflow activity detected" >&2
    fi
    
    return $found_status
}

# Function to wait for workflow completion
wait_for_workflow() {
    local issue_number=$1
    local max_wait=300  # 5 minutes
    local wait_time=0
    local check_interval=15
    
    print_status "Waiting for workflow to process issue #$issue_number..."
    
    while [ $wait_time -lt $max_wait ]; do
        print_status "Check cycle $((wait_time/check_interval + 1)): Checking issue and workflow status..."
        
        # Check if issue is closed
        print_status "Checking issue state..."
        ISSUE_STATE=$(gh issue view "$issue_number" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state' 2>/dev/null)
        
        if [ "$ISSUE_STATE" = "CLOSED" ]; then
            print_success "Issue #$issue_number has been closed"
            return 0
        fi
        
        print_status "Issue #$issue_number is $ISSUE_STATE"
        
        # Check workflow runs
        print_status "Checking workflow status..."
        check_workflow_runs "$issue_number"
        workflow_status=$?
        
        print_status "Workflow check returned status: $workflow_status"
        
        if [ $workflow_status -eq 2 ]; then
            print_error "Workflow failed - stopping wait"
            return 2
        fi
        
        print_status "Issue #$issue_number is still $ISSUE_STATE... waiting ($wait_time/${max_wait}s)"
        
        print_status "Sleeping for $check_interval seconds..."
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    print_warning "Workflow did not complete within $max_wait seconds"
    
    # Final check of workflow runs
    print_status "Final workflow status check..."
    check_workflow_runs "$issue_number"
    
    return 1
}

# Function to check if entry was created
check_entry_created() {
    print_status "Checking if registry entry was created..."
    
    local expected_path="registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
    
    if [ -f "$expected_path" ]; then
        print_success "Registry entry created at: $expected_path"
        return 0
    else
        print_error "Registry entry not found at: $expected_path"
        return 1
    fi
}

# Function to check issue comments for success/failure
check_issue_comments() {
    local issue_number=$1
    print_status "Checking issue comments for workflow results..."
    
    gh issue view "$issue_number" --repo "$REPO_OWNER/$REPO_NAME" --comments | while IFS= read -r line; do
        if [[ $line == *"✅"* ]]; then
            print_success "Found success comment: $line"
        elif [[ $line == *"❌"* ]]; then
            print_error "Found error comment: $line"
        fi
    done
}

# Function to cleanup created entry
cleanup_entry() {
    print_status "Cleaning up created registry entry..."
    
    local registry_path="registry/mcpproviders/$TEST_PROVIDER"
    
    if [ -d "$registry_path" ]; then
        rm -rf "$registry_path"
        print_success "Removed registry entry at: $registry_path"
        
        # If this was the only test, commit the cleanup
        if git status --porcelain | grep -q "D  $registry_path"; then
            git add "$registry_path"
            git commit -m "Clean up test MCP entry: $TEST_PROVIDER/$TEST_SERVER"
            git push origin main
            print_success "Committed cleanup to repository"
        fi
    else
        print_warning "Registry entry not found for cleanup: $registry_path"
    fi
}

# Function to close and delete test issue
cleanup_issue() {
    local issue_number=$1
    print_status "Cleaning up test issue #$issue_number..."
    
    # Close the issue if it's not already closed
    ISSUE_STATE=$(gh issue view "$issue_number" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state')
    if [ "$ISSUE_STATE" != "CLOSED" ]; then
        gh issue close "$issue_number" --repo "$REPO_OWNER/$REPO_NAME" --comment "Test completed, closing issue"
    fi
    
    print_success "Test issue #$issue_number handled"
}

# Main test execution
main() {
    print_status "Starting MCP workflow test..."
    print_status "Repository: $REPO_OWNER/$REPO_NAME"
    print_status "Test Provider: $TEST_PROVIDER"
    print_status "Test Server: $TEST_SERVER"
    
    # Check prerequisites
    check_gh_cli
    
    # Create test issue
    ISSUE_NUMBER=$(create_issue)
    
    # Wait for workflow to complete
    wait_result=$(wait_for_workflow "$ISSUE_NUMBER"; echo $?)
    
    case $wait_result in
        0)
            # Workflow completed successfully, check if entry was created
            if check_entry_created; then
                print_success "✅ MCP workflow test PASSED!"
                
                # Show the created entry
                print_status "Created entry contents:"
                cat "registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
                
                # Cleanup
                cleanup_entry
            else
                print_error "❌ MCP workflow test FAILED - Entry not created despite workflow completion"
            fi
            ;;
        2)
            print_error "❌ MCP workflow test FAILED - Workflow execution failed"
            ;;
        *)
            print_error "❌ MCP workflow test FAILED - Workflow timeout or other issue"
            ;;
    esac
    
    # Check issue comments for details
    check_issue_comments "$ISSUE_NUMBER"
    
    # Cleanup issue
    cleanup_issue "$ISSUE_NUMBER"
    
    print_status "Test completed"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 