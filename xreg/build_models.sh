#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO_ROOT=$(readlink -f "$SCRIPT_DIR/..")
OPENAPI_OUTPUT_DIR="$REPO_ROOT/openapi"
SCHEMA_OUTPUT_DIR="$REPO_ROOT/schema"

echo "Building unified xRegistry AI schemas..."
echo "Script directory: $SCRIPT_DIR"
echo "Repository root: $REPO_ROOT"

# Ensure output directories exist
mkdir -p "$OPENAPI_OUTPUT_DIR" "$SCHEMA_OUTPUT_DIR"

# Check if we need to clone the xregistry spec
if [ ! -d "$SCRIPT_DIR/.xregistry-spec" ]; then
    echo "Cloning xRegistry specification..."
    git clone https://github.com/xregistry/spec.git "$SCRIPT_DIR/.xregistry-spec"
fi

SCHEMA_GENERATOR="$SCRIPT_DIR/schema-generator.py"

# List available models
echo "Available models:"
python "$SCHEMA_GENERATOR" --list

echo ""
echo "Generating unified OpenAPI specification..."
python "$SCHEMA_GENERATOR" \
    --type openapi \
    --output "$OPENAPI_OUTPUT_DIR/openapi.json" \
    --models

echo ""
echo "Generating unified JSON Schema..."
python "$SCHEMA_GENERATOR" \
    --type json-schema \
    --output "$SCHEMA_OUTPUT_DIR/json-schema.json" \
    --models

echo ""
echo "Generating unified Avro Schema..."
python "$SCHEMA_GENERATOR" \
    --type avro-schema \
    --output "$SCHEMA_OUTPUT_DIR/avro-schema.json" \
    --models

echo ""
echo "Schema generation completed!"
echo "OpenAPI: $OPENAPI_OUTPUT_DIR/openapi.json"
echo "JSON Schema: $SCHEMA_OUTPUT_DIR/json-schema.json"
echo "Avro Schema: $SCHEMA_OUTPUT_DIR/avro-schema.json" 