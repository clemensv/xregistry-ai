#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO_ROOT=$(readlink -f "$SCRIPT_DIR/..")

echo "Building unified xRegistry AI repository..."
echo "Repository root: $REPO_ROOT"

# Step 1: Generate issue templates and workflows from metadata
echo ""
echo "Step 1: Generating issue templates and workflows..."
python "$SCRIPT_DIR/generate-issue-templates.py"

# Step 2: Generate schemas from all models
echo ""
echo "Step 2: Generating unified schemas..."
bash "$SCRIPT_DIR/build_models.sh"

# Step 3: Copy registry content from both source repositories (if they exist)
echo ""
echo "Step 3: Setting up registry content..."

# Copy A2A registry content if source exists
if [ -d "$REPO_ROOT/../xregistry-a2a/registry" ]; then
    echo "  Copying A2A registry content..."
    cp -r "$REPO_ROOT/../xregistry-a2a/registry/agentcardproviders" "$REPO_ROOT/registry/" 2>/dev/null || true
fi

# Copy MCP registry content if source exists
if [ -d "$REPO_ROOT/../xregistry-mcp/registry" ]; then
    echo "  Copying MCP registry content..."
    cp -r "$REPO_ROOT/../xregistry-mcp/registry/mcpproviders" "$REPO_ROOT/registry/" 2>/dev/null || true
fi

# Copy index content
if [ -d "$REPO_ROOT/../xregistry-a2a/index" ]; then
    echo "  Copying A2A index content..."
    cp -r "$REPO_ROOT/../xregistry-a2a/index"/* "$REPO_ROOT/index/" 2>/dev/null || true
fi

if [ -d "$REPO_ROOT/../xregistry-mcp/index" ]; then
    echo "  Copying MCP index content..."
    cp -r "$REPO_ROOT/../xregistry-mcp/index"/* "$REPO_ROOT/index/" 2>/dev/null || true
fi

echo ""
echo "Step 4: Making scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh

echo ""
echo "Unified xRegistry AI build completed successfully!"
echo ""
echo "Generated files:"
echo "  - OpenAPI: $REPO_ROOT/openapi/openapi.json"
echo "  - JSON Schema: $REPO_ROOT/schema/json-schema.json"  
echo "  - Avro Schema: $REPO_ROOT/schema/avro-schema.json"
echo "  - Issue templates: $REPO_ROOT/.github/ISSUE_TEMPLATE/"
echo "  - Workflows: $REPO_ROOT/.github/workflows/"
echo ""
echo "Available models:"
python "$SCRIPT_DIR/schema-generator.py" --list 