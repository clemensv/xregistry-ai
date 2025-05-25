#!/bin/bash

# Simple deployment script for xRegistry AI
# This bypasses the complex xRegistry server setup and creates a basic static site

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO_ROOT=$(readlink -f "$SCRIPT_DIR/..")
LIVE_DIR="$REPO_ROOT/live"

echo "🚀 Starting simplified xRegistry AI deployment..."
echo "Repository root: $REPO_ROOT"

# Clean up previous builds
echo "🧹 Cleaning up previous builds..."
rm -rf "$LIVE_DIR"
mkdir -p "$LIVE_DIR"

# Generate search indices
echo "📊 Generating search indices..."
cd "$REPO_ROOT/index"
python build_index.py || echo "⚠️  Index generation had warnings (npm not available)"

# Copy registry structure to live directory
echo "📁 Copying registry structure..."
cp -r "$REPO_ROOT/registry"/* "$LIVE_DIR/"

# Copy generated indices
echo "📋 Copying search indices..."
cp "$REPO_ROOT/index"/*.json "$LIVE_DIR/" 2>/dev/null || echo "⚠️  Some index files may be missing"

# Generate schemas
echo "🔧 Generating schemas..."
cd "$REPO_ROOT/xreg"
mkdir -p "$REPO_ROOT/schema" "$REPO_ROOT/openapi"

# Generate schemas using the schema generator
python schema-generator.py --models --type json-schema --output "$REPO_ROOT/schema/json-schema.json" || echo "⚠️  JSON schema generation failed"
python schema-generator.py --models --type openapi --output "$REPO_ROOT/openapi/openapi.json" || echo "⚠️  OpenAPI generation failed"
python schema-generator.py --models --type avro-schema --output "$REPO_ROOT/schema/avro-schema.json" || echo "⚠️  Avro schema generation failed"

# Copy schemas to live directory
echo "📄 Copying schemas..."
mkdir -p "$LIVE_DIR/schema" "$LIVE_DIR/openapi"
cp "$REPO_ROOT/schema"/*.json "$LIVE_DIR/schema/" 2>/dev/null || echo "⚠️  No schema files to copy"
cp "$REPO_ROOT/openapi"/*.json "$LIVE_DIR/openapi/" 2>/dev/null || echo "⚠️  No OpenAPI files to copy"

# Copy Azure configuration
echo "⚙️  Copying Azure configuration..."
cp "$REPO_ROOT/xreg/registry-staticwebapp.config.json" "$LIVE_DIR/staticwebapp.config.json" 2>/dev/null || echo "⚠️  No Azure config to copy"

# Create a simple info file
echo "ℹ️  Creating deployment info..."
cat > "$LIVE_DIR/deployment-info.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "simplified-deployment",
  "generator": "simple-deploy.sh",
  "registry": {
    "mcpProviders": $(find "$REPO_ROOT/registry/mcpproviders" -name "index.json" | wc -l),
    "agentCardProviders": $(find "$REPO_ROOT/registry/agentcardproviders" -name "index.json" | wc -l)
  }
}
EOF

# Display summary
echo ""
echo "✅ Simplified deployment completed!"
echo "📁 Live directory: $LIVE_DIR"
echo "📊 Registry structure:"
ls -la "$LIVE_DIR" | head -20
echo ""
echo "🔍 Registry content summary:"
echo "   - MCP Providers: $(find "$REPO_ROOT/registry/mcpproviders" -name "index.json" | wc -l) providers"
echo "   - Agent Card Providers: $(find "$REPO_ROOT/registry/agentcardproviders" -name "index.json" | wc -l) providers"
echo "   - Search indices: $(ls "$LIVE_DIR"/*.json 2>/dev/null | wc -l) files"
echo ""
echo "🌐 Ready for deployment to:"
echo "   - GitHub Pages"
echo "   - Azure Static Web Apps"
echo "   - Any static hosting service" 