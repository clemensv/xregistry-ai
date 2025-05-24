# Contributing to xRegistry AI

Thank you for your interest in contributing to the unified xRegistry AI repository! This guide will help you add new AI protocol models to the registry.

## Overview

This repository uses a metadata-driven architecture where new AI protocol models can be added by:

1. **Adding a model definition** in the `models/` directory
2. **Updating the registry configuration** to include metadata for the new model
3. **Submitting a pull request** which will automatically validate and generate all necessary components

## Adding a New Model

### Step 1: Create the Model Definition

Create a new directory under `models/` with your protocol name:

```bash
mkdir models/your-protocol
```

Create a `model.json` file following the [xRegistry specification](https://github.com/xregistry/spec):

```json
{
  "groups": {
    "yourprotocolproviders": {
      "plural": "yourprotocolproviders",
      "singular": "yourprotocolprovider",
      "description": "Your Protocol Provider organizations",
      "resources": {
        "implementations": {
          "plural": "implementations", 
          "singular": "implementation",
          "description": "Protocol implementations",
          "maxversions": 0,
          "hasdocument": true,
          "attributes": {
            "name": {
              "name": "name",
              "type": "string",
              "required": true,
              "description": "Name of the implementation"
            },
            "version": {
              "name": "version", 
              "type": "string",
              "required": true,
              "description": "Version of the implementation"
            },
            "description": {
              "name": "description",
              "type": "string", 
              "description": "Description of the implementation"
            }
          }
        }
      }
    }
  }
}
```

### Step 2: Update Registry Configuration

Add your model to `xreg/registry-config.json`:

```json
{
  "registry": {
    "name": "xRegistry AI",
    "description": "Unified registry for AI protocol implementations",
    "baseUrl": "https://xregistry-ai.github.io"
  },
  "models": {
    "existing-model": { ... },
    "your-protocol": {
      "name": "Your Protocol Name",
      "description": "Description of your protocol",
      "groupSingular": "yourprotocolprovider",
      "groupPlural": "yourprotocolproviders",
      "resourceSingular": "implementation", 
      "resourcePlural": "implementations",
      "manifestFile": "your-manifest.json",
      "hasDocument": true,
      "issueTitle": "Registry submission for Your Protocol",
      "issueAbout": "File this issue to add a new Your Protocol implementation"
    }
  },
  "validationRules": { ... }
}
```

### Step 3: Submit a Pull Request

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b add-your-protocol-model
   ```
3. **Commit your changes**:
   ```bash
   git add models/your-protocol/model.json xreg/registry-config.json
   git commit -m "Add Your Protocol model"
   ```
4. **Push and create a PR**:
   ```bash
   git push origin add-your-protocol-model
   ```

## Automated Validation

When you submit a PR, the following automated validations will run:

### 🔍 **Model File Validation**
- **JSON Syntax**: Validates that your model.json is valid JSON
- **Structure**: Ensures required fields (`groups`, `singular`, `plural`) are present
- **Schema**: Validates against xRegistry specification requirements

### 🛠️ **Schema Generation Testing**  
- **Discovery**: Tests that your model is properly discovered
- **Generation**: Validates that unified schemas can be generated with your model
- **Individual**: Tests schema generation for your specific model

### ⚙️ **Configuration Validation**
- **Syntax**: Validates registry-config.json syntax
- **Structure**: Ensures all required fields are present for your model
- **Completeness**: Verifies model configuration completeness

### 📋 **Template Generation Testing**
- **Issue Templates**: Generates GitHub issue templates for your protocol
- **Workflows**: Creates automated validation workflows
- **Integration**: Tests integration with the existing system

## Automatic Generation

Once your PR is merged, the system will automatically:

✅ **Generate unified schemas** including your new model  
✅ **Create issue templates** for protocol submissions  
✅ **Set up GitHub Actions workflows** for automated validation  
✅ **Update the command-line interface** to include your model  
✅ **Generate API documentation** with your protocol endpoints  

## Model Structure Guidelines

### Required Fields

Your model **must** include:

- `groups`: Object containing protocol group definitions
- For each group:
  - `singular`: Singular form of the group name
  - `plural`: Plural form of the group name
  - `resources`: Object containing resource definitions
- For each resource:
  - `singular`: Singular form of the resource name
  - `plural`: Plural form of the resource name

### Recommended Fields

For better integration, include:

- `description`: Clear descriptions for groups and resources
- `attributes`: Detailed attribute definitions with types
- `required`: Mark required attributes appropriately
- `maxversions`: Specify versioning behavior
- `hasdocument`: Indicate if resources have document content

### Naming Conventions

Follow these naming patterns:

- **Group names**: `{protocol}providers` (e.g., `mcpproviders`, `agentcardproviders`)
- **Resource names**: Descriptive plural/singular forms (e.g., `servers`/`server`)
- **Attribute names**: Lowercase with underscores (e.g., `version_detail`)
- **Model directory**: Lowercase, hyphenated (e.g., `agent-to-agent`, `model-context-protocol`)

## Registry Configuration Fields

When adding to `registry-config.json`, include:

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Human-readable protocol name | `"Model Context Protocol (MCP)"` |
| `description` | Brief protocol description | `"MCP server registry"` |
| `groupSingular` | Singular group name from model | `"mcpprovider"` |
| `groupPlural` | Plural group name from model | `"mcpproviders"` |
| `resourceSingular` | Singular resource name | `"server"` |
| `resourcePlural` | Plural resource name | `"servers"` |
| `manifestFile` | Expected manifest filename | `"mcp.json"` |
| `hasDocument` | Whether resources include document content | `true`/`false` |
| `issueTitle` | GitHub issue template title | `"Registry submission for MCP Server"` |
| `issueAbout` | GitHub issue template description | `"File this issue when..."` |

## Testing Your Model Locally

Before submitting a PR, test your model locally:

```bash
# Navigate to the xreg directory
cd xreg

# Test model discovery
python schema-generator.py --list

# Test schema generation for your model
python schema-generator.py --models your-protocol --type json-schema

# Test unified schema generation
python schema-generator.py --models --type openapi

# Generate issue templates
python generate-issue-templates.py

# Run full build
./build-all.sh
```

## Model Examples

### Simple Protocol
```json
{
  "groups": {
    "simpleproviders": {
      "singular": "simpleprovider",
      "plural": "simpleproviders", 
      "description": "Simple protocol providers",
      "resources": {
        "tools": {
          "singular": "tool",
          "plural": "tools",
          "description": "Protocol tools",
          "attributes": {
            "name": {"type": "string", "required": true},
            "version": {"type": "string", "required": true}
          }
        }
      }
    }
  }
}
```

### Complex Protocol with Nested Attributes
```json
{
  "groups": {
    "complexproviders": {
      "singular": "complexmachinery",
      "plural": "complexmachineries",
      "description": "Complex protocol providers",
      "resources": {
        "engines": {
          "singular": "engine", 
          "plural": "engines",
          "description": "Protocol engines",
          "maxversions": 5,
          "attributes": {
            "metadata": {
              "type": "object",
              "attributes": {
                "name": {"type": "string", "required": true},
                "author": {"type": "string"},
                "tags": {
                  "type": "array", 
                  "item": {"type": "string"}
                }
              }
            },
            "capabilities": {
              "type": "array",
              "item": {
                "type": "object",
                "attributes": {
                  "feature": {"type": "string"},
                  "enabled": {"type": "boolean"}
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## Support

If you need help:

1. **Check existing models** in `models/` for examples
2. **Review the validation errors** in your PR checks  
3. **Read the [xRegistry specification](https://github.com/xregistry/spec)**
4. **Open an issue** for guidance

## What Happens After Your PR is Merged

1. **Automatic Schema Generation**: Your model is included in unified schemas
2. **Issue Template Creation**: Users can submit registrations for your protocol
3. **API Endpoint Generation**: REST API endpoints are created for your protocol
4. **CLI Integration**: Your model appears in `--list` and can be used with `--models`
5. **Documentation Updates**: Your protocol appears in generated documentation

Your new protocol model will be fully integrated into the xRegistry AI ecosystem! 🎉 