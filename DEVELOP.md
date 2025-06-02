# Development Guide

## Repository Structure

```
xregistry-ai/
├── models/                          # Protocol-specific models
│   ├── a2a/model.json              # A2A protocol model definition
│   └── mcp/model.json              # MCP protocol model definition
├── xreg/                           # Core registry tools
│   ├── schema-generator.py         # Enhanced schema generator
│   ├── build_models.sh            # Schema generation script
│   ├── build_registry.sh          # Main registry build script
│   ├── build-all.sh               # Master build script
│   ├── registry-config.json       # Metadata configuration
│   ├── generate-issue-templates.py # Auto-generate issue templates
│   └── validate-model.py          # Model validation script
├── registry/                       # Registry content (auto-generated)
│   ├── mcpproviders/              # MCP server registrations
│   └── agentcardproviders/        # A2A agent registrations
├── .github/                        # GitHub automation
│   ├── ISSUE_TEMPLATE/            # Model-specific issue templates
│   ├── workflows/                 # CI/CD workflows
│   └── scripts/                   # Validation scripts
├── openapi/                        # Generated schemas
├── schema/                         # Generated schemas
├── index/                          # Search indices
└── site/                          # Static site output
```

## Core Components

### Schema Generator (`xreg/schema-generator.py`)

Central tool for model and schema management:

```python
# List available models
python schema-generator.py --list

# Generate unified schemas from all models
python schema-generator.py --models --type openapi
python schema-generator.py --models --type json-schema
python schema-generator.py --models --type avro-schema

# Generate protocol-specific schemas
python schema-generator.py --models mcp --type json-schema
```

Features:
- Auto-discovers models from `models/` directory
- Generates unified schemas across all protocols
- Supports OpenAPI, JSON Schema, and Avro formats
- Protocol-specific schema generation

### Registry Builder (`xreg/build_registry.sh`)

Main orchestration script that:
1. Builds custom xRegistry server image (if `XRSERVER_COMMIT` specified)
2. Starts containerized xRegistry server
3. Loads protocol models
4. Ingests registry data from GitHub repositories
5. Exports static registry data
6. Builds Angular SPA with registry integration

Key configuration:
```bash
XRSERVER_COMMIT="abbec09"  # Custom server build commit
```

### Configuration System

#### Registry Config (`xreg/registry-config.json`)
Metadata-driven configuration defining:
- Available protocol models (A2A, MCP, etc.)
- Submission parameters for each protocol
- Validation rules
- Issue template generation settings

#### Model Definitions (`models/*/model.json`)
xRegistry-compliant model definitions with:
- **Groups**: Organizational units (e.g., `mcpproviders`)
- **Resources**: Items within groups (e.g., `servers`)
- **Attributes**: Schema definitions for resources
- **Metadata**: Versioning and validation settings

## Build Process

### 1. Model & Schema Generation
```bash
cd xreg
./build_models.sh  # Generates schemas from all models
```

### 2. Issue Template Generation
```bash
python generate-issue-templates.py  # Creates GitHub issue templates
```

### 3. Registry Data Build
```bash
./build_registry.sh  # Full registry build and site generation
```

### 4. Static Site Deployment
GitHub Actions automatically:
- Builds registry data into `static-site` branch
- Deploys to Azure Static Web Apps
- Updates search indices

## GitHub Actions Workflows

### Issue Processing
- `issues-a2a.yml`: Validates and ingests A2A submissions
- `issues-mcp.yml`: Validates and ingests MCP submissions

### Build & Deploy
- `build-static.yml`: Builds registry data and Angular SPA
- `deploy-azure-static.yml`: Deploys to Azure Static Web Apps
- `build-schemas.yml`: Regenerates schemas on model changes

### Pull Request Validation
- `pr-model-validation.yml`: Validates new models and configurations

## Development Workflow

### Adding New Protocol Models

1. **Create Model Definition**
   ```bash
   mkdir models/new-protocol
   # Create models/new-protocol/model.json following xRegistry spec
   ```

2. **Update Configuration**
   ```json
   // Add to xreg/registry-config.json
   {
     "protocols": {
       "new-protocol": {
         "groupSingular": "newprotocolprovider",
         "groupPlural": "newprotocolproviders",
         "resourceSingular": "implementation", 
         "resourcePlural": "implementations",
         "fileName": "newprotocol.json"
       }
     }
   }
   ```

3. **Test Locally**
   ```bash
   cd xreg
   python validate-model.py new-protocol
   ./build-all.sh
   ```

4. **Submit PR**
   Automated validation will verify the model and generate templates.

### Local Development Setup

```bash
# Prerequisites
pip install pandas jsonpointer

# Full build
cd xreg && ./build-all.sh

# Schema generation only
python schema-generator.py --models --type openapi

# Validate specific model
python validate-model.py mcp --config-only
```

## Architecture Patterns

### Metadata-Driven Design
The entire system operates from configuration files:
- Models define protocol schemas
- Registry config controls issue templates and validation
- Build scripts auto-generate workflows and schemas

### Container-Based Registry Server
Uses containerized xRegistry server for:
- Protocol model validation
- Registry data management
- Static export generation

### Hybrid Static/Dynamic Deployment
- **Static**: Registry data as static JSON files
- **Dynamic**: Angular SPA for browsing and search
- **Serverless**: GitHub Actions for processing submissions

### Issue-Driven Submissions
Protocol implementations submitted via GitHub issues:
- Structured YAML templates
- Automated validation and ingestion
- Remote repository file fetching

## Testing Strategy

### Model Validation
- JSON schema validation
- xRegistry specification compliance
- Schema generation testing

### Issue Processing
- YAML template validation
- Remote file accessibility
- Protocol-specific validation rules

### Build Process
- Schema generation from all models
- Static site generation
- Template and workflow generation

## Extension Points

### Adding New Output Formats
Extend `schema-generator.py` with new `--type` options.

### Custom Validation Rules
Add protocol-specific validators in `.github/scripts/`.

### Additional Deployment Targets
Create new workflows following the Azure Static Web Apps pattern.

### Search Enhancement
Extend index builders in `index/` directory for new search capabilities. 