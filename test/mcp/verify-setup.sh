#!/bin/bash

# Verification script for MCP test setup
# Checks that all required files and dependencies are in place

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

print_status "Verifying MCP test setup..."

# Check if we're in the right directory
if [[ ! -d "test/mcp" ]]; then
    print_error "Not in xregistry-ai root directory or test/mcp doesn't exist"
    exit 1
fi

print_success "In correct directory structure"

# Check if required files exist
FILES_TO_CHECK=(
    "test/mcp/mcp.json"
    "test/mcp/test-mcp-workflow.sh"
    "test/mcp/test-mcp-workflow.ps1"
    "test/mcp/README.md"
    ".github/workflows/issues-mcp.yml"
    ".github/scripts/validate-submission.js"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
    fi
done

# Check if mcp.json is valid JSON
print_status "Validating mcp.json..."
if command -v jq &> /dev/null; then
    if jq empty test/mcp/mcp.json 2>/dev/null; then
        print_success "mcp.json is valid JSON"
    else
        print_error "mcp.json is not valid JSON"
    fi
else
    print_warning "jq not available, skipping JSON validation"
fi

# Check GitHub CLI and authentication
print_status "Checking GitHub CLI..."
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -n1)
    print_success "GitHub CLI available: $GH_VERSION"
    
    # Check authentication status
    if gh auth status &> /dev/null; then
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
        print_success "GitHub CLI is authenticated as: $GH_USER"
    else
        print_warning "GitHub CLI is not authenticated"
        
        # Check GitHub token
        if [[ -n "$GITHUB_TOKEN" ]]; then
            TOKEN_LENGTH=${#GITHUB_TOKEN}
            print_success "GITHUB_TOKEN is set (length: $TOKEN_LENGTH characters)"
        else
            print_warning "GITHUB_TOKEN environment variable not set"
            print_warning "Please either:"
            print_warning "  1. Run 'gh auth login' to authenticate, or"
            print_warning "  2. Set GITHUB_TOKEN with: export GITHUB_TOKEN=your_token_here"
        fi
    fi
else
    print_error "GitHub CLI (gh) not found. Install from https://cli.github.com/"
fi

# Check if scripts are executable
print_status "Checking script permissions..."
if [[ -x "test/mcp/test-mcp-workflow.sh" ]]; then
    print_success "test-mcp-workflow.sh is executable"
else
    print_warning "test-mcp-workflow.sh is not executable. Run: chmod +x test/mcp/test-mcp-workflow.sh"
fi

# Check git configuration
print_status "Checking git configuration..."
if git config user.name &> /dev/null && git config user.email &> /dev/null; then
    GIT_USER=$(git config user.name)
    GIT_EMAIL=$(git config user.email)
    print_success "Git configured: $GIT_USER <$GIT_EMAIL>"
else
    print_warning "Git user not configured. May affect commit operations."
fi

# Check if we're in a git repository
if git rev-parse --git-dir &> /dev/null; then
    CURRENT_BRANCH=$(git branch --show-current)
    print_success "In git repository, current branch: $CURRENT_BRANCH"
else
    print_error "Not in a git repository"
fi

# Check repository remote
print_status "Checking git remote..."
if git remote get-url origin &> /dev/null; then
    REMOTE_URL=$(git remote get-url origin)
    print_success "Git remote: $REMOTE_URL"
    
    if [[ "$REMOTE_URL" == *"clemensv/xregistry-ai"* ]]; then
        print_success "Remote points to clemensv/xregistry-ai"
    else
        print_warning "Remote does not point to clemensv/xregistry-ai"
        print_warning "This may cause issues with the test"
    fi
else
    print_error "No git remote 'origin' configured"
fi

# Check workflow file syntax
print_status "Checking workflow file..."
if command -v yamllint &> /dev/null; then
    if yamllint .github/workflows/issues-mcp.yml &> /dev/null; then
        print_success "Workflow YAML syntax is valid"
    else
        print_warning "Workflow YAML may have syntax issues"
    fi
else
    print_warning "yamllint not available, skipping YAML validation"
fi

# Final summary
echo ""
print_status "Verification complete!"
echo ""

# Check if authenticated and adjust instructions
if gh auth status &> /dev/null; then
    print_status "✅ Ready to run the test!"
    echo "  Run: ./test/mcp/test-mcp-workflow.sh"
    echo "  Or use PowerShell: ./test/mcp/test-mcp-workflow.ps1"
else
    print_status "To run the test:"
    echo "  1. Authenticate: gh auth login (or export GITHUB_TOKEN=your_token_here)"
    echo "  2. Run: ./test/mcp/test-mcp-workflow.sh"
    echo "  3. Or use PowerShell: ./test/mcp/test-mcp-workflow.ps1"
fi

echo ""
print_status "For help: ./test/mcp/test-mcp-workflow.ps1 -Help" 