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
    print_status "Creating test issue..."
    
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
    ISSUE_NUMBER=$(gh issue create \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --title "$ISSUE_TITLE" \
        --body "$ISSUE_BODY" | grep -o '#[0-9]*' | sed 's/#//')
    
    if [ -z "$ISSUE_NUMBER" ]; then
        print_error "Failed to create issue"
        exit 1
    fi
    
    # Try to add label if it exists (optional)
    if gh label list --repo "$REPO_OWNER/$REPO_NAME" | grep -q "mcp-submission"; then
        gh issue edit "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --add-label "mcp-submission" 2>/dev/null || true
        print_status "Added mcp-submission label to issue"
    fi
    
    print_success "Created issue #$ISSUE_NUMBER"
    echo "$ISSUE_NUMBER"
}

# Function to wait for workflow completion
wait_for_workflow() {
    local issue_number=$1
    local max_wait=300  # 5 minutes
    local wait_time=0
    local check_interval=15
    
    print_status "Waiting for workflow to process issue #$issue_number..."
    
    while [ $wait_time -lt $max_wait ]; do
        # Check if issue is closed
        ISSUE_STATE=$(gh issue view "$issue_number" --repo "$REPO_OWNER/$REPO_NAME" --json state --jq '.state')
        
        if [ "$ISSUE_STATE" = "CLOSED" ]; then
            print_success "Issue #$issue_number has been closed"
            return 0
        fi
        
        print_status "Issue #$issue_number is still $ISSUE_STATE... waiting ($wait_time/${max_wait}s)"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    print_warning "Workflow did not complete within $max_wait seconds"
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
    if wait_for_workflow "$ISSUE_NUMBER"; then
        # Check if entry was created successfully
        if check_entry_created; then
            print_success "✅ MCP workflow test PASSED!"
            
            # Show the created entry
            print_status "Created entry contents:"
            cat "registry/mcpproviders/$TEST_PROVIDER/servers/$TEST_SERVER/index.json"
            
            # Cleanup
            cleanup_entry
        else
            print_error "❌ MCP workflow test FAILED - Entry not created"
        fi
    else
        print_error "❌ MCP workflow test FAILED - Workflow timeout"
    fi
    
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