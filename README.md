<img src="https://github.com/cncf/artwork/raw/main/projects/xregistry/horizontal/color/xregistry-horizontal-color.svg" alt="xRegistry" style="max-height: 30px;">

# xRegistry for AI

The field of Artificial Intelligence (AI) is rapidly evolving and is a great marketplace of ideas and, for now, competing approaches. There are and will be numerous metadata declarations for models and agents and interactions between agents and all sorts of other things we don't even know yet. This repository is an extensible registry with a consistent API, CNCF xRegistry, for ALL these metadata files. You can bring new models, which extends this registry, or you can file issues that will ingest descriptions of your assets into the registry. It is required for those assets to exist in a publicly accessible Git repository (any provider, not just Github) and for each model type, your repository must contain a file with a specific file name. The repos will be scanned on a regular basis to make sure that your registration is up to date.

## Currently Supported Protocols

- **Agent-to-Agent (A2A)** protocol registrations (AgentCards)
- **Model Context Protocol (MCP)** server registrations
- **Extensible architecture** for adding new AI protocol types

## Repository Structure

```
xregistry-ai/
├── models/                          # Protocol-specific models
│   ├── a2a/model.json              # A2A protocol model definition
│   └── mcp/model.json              # MCP protocol model definition
├── xreg/                           # Core registry tools
│   ├── schema-generator.py         # Enhanced schema generator
│   ├── build_models.sh            # Schema generation script
│   ├── build-all.sh               # Master build script
│   ├── registry-config.json       # Metadata configuration
│   ├── generate-issue-templates.py # Auto-generate issue templates
│   └── validate-model.py          # Model validation script
├── openapi/                        # Generated OpenAPI specifications
│   └── openapi.json               # Unified OpenAPI spec
├── schema/                         # Generated JSON/Avro schemas
│   ├── json-schema.json           # Unified JSON schema
│   └── avro-schema.json           # Unified Avro schema
├── .github/                        # Auto-generated GitHub workflows
│   ├── ISSUE_TEMPLATE/            # Model-specific issue templates
│   ├── workflows/                 # Automated build & validation
│   └── scripts/                   # Validation scripts
├── registry/                       # Registry content
├── index/                          # Search indices
└── site/                          # Web interface
```

## Key Features

### 🔄 Metadata-Driven Architecture

The entire system is driven by [`xreg/registry-config.json`](xreg/registry-config.json), which defines:

- Available protocol models (A2A, MCP, etc.)
- Submission parameters for each protocol
- Validation rules
- Issue template generation settings

### 🛠️ Enhanced Schema Generator

The [`schema-generator.py`](xreg/schema-generator.py) can:

- **Discover models automatically** from the `models/` directory
- **List available models**: `python schema-generator.py --list`
- **Generate unified schemas** from all models: `python schema-generator.py --models --type openapi`
- **Generate protocol-specific schemas**: `python schema-generator.py --models a2a --type json-schema`

### 🤖 Automated Issue Templates

Issue templates and GitHub Actions workflows are automatically generated for each protocol based on the metadata configuration.

### ⚡ Automatic Schema Generation

Schemas are automatically regenerated when:
- Model definitions change (`models/**/*.json`)
- Configuration changes (`xreg/registry-config.json`) 
- Generator code changes

### 🔍 Pull Request Validation

Automated validation runs on every PR that includes new models or changes:
- **Model Structure Validation**: Ensures proper JSON format and required fields
- **Schema Generation Testing**: Verifies that schemas can be generated with new models
- **Template Generation**: Tests issue template and workflow creation
- **Consistency Checking**: Validates config consistency with model definitions

## Getting Started

### Prerequisites

- Python 3.11+
- Bash (for build scripts)
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd xregistry-ai
```

2. Install Python dependencies:
```bash
pip install jsonpointer
```

3. Build all schemas and templates:
```bash
cd xreg
./build-all.sh
```

### Adding New Models via Pull Request

When you submit a PR with new models, our automated validation system will:

1. **🔍 Detect Changes**: Automatically identify new or modified models
2. **✅ Validate Structure**: Check JSON syntax and model structure  
3. **🛠️ Test Generation**: Verify schema generation works with your model
4. **📋 Generate Templates**: Create issue templates and workflows
5. **💬 Provide Feedback**: Comment on your PR with validation results

The PR validation workflow runs on every pull request and provides detailed feedback about any issues.

## Usage

### List Available Models

```bash
cd xreg
python schema-generator.py --list
```

### Generate Unified Schemas

```bash
# Generate all schemas from all models
./build_models.sh

# Or generate specific types
python schema-generator.py --models --type openapi --output ../openapi/openapi.json
python schema-generator.py --models --type json-schema --output ../schema/json-schema.json
```

### Generate Protocol-Specific Schemas

```bash
# Generate schema for specific models only
python schema-generator.py --models a2a mcp --type json-schema
python schema-generator.py --models mcp --type openapi
```

### Validate a New Model Locally

```bash
cd xreg
# Validate a model before submitting PR
python validate-model.py your-model-name

# Test only configuration
python validate-model.py your-model-name --config-only

# Skip schema generation test
python validate-model.py your-model-name --no-schema-test
```

### Add a New Protocol Model

1. Create a new directory in `models/`: `models/new-protocol/`
2. Add your model definition: `models/new-protocol/model.json`
3. Update `xreg/registry-config.json` to include the new protocol
4. Test locally: `python validate-model.py new-protocol`
5. Submit a pull request

The system will automatically:
- ✅ Generate issue templates for the new protocol
- ✅ Create GitHub Actions workflows
- ✅ Include the model in unified schema generation
- ✅ Update validation scripts

## Model Structure

Each model follows the xRegistry specification and defines:

- **Groups**: Top-level organizational units (e.g., `agentcardproviders`, `mcpproviders`)
- **Resources**: Items within groups (e.g., `agentcards`, `servers`)
- **Attributes**: Schema definitions for the resources
- **Metadata**: Versioning, validation, and other behavioral settings

Example model structure:
```json
{
  "groups": {
    "protocolproviders": {
      "plural": "protocolproviders",
      "singular": "protocolprovider", 
      "description": "Protocol provider organizations",
      "resources": {
        "implementations": {
          "plural": "implementations",
          "singular": "implementation",
          "description": "Protocol implementations",
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

## Registry Submissions

Users can submit new entries via GitHub issues. The system automatically:

1. **Validates** the submission format and required fields
2. **Fetches** the manifest file from the specified repository
3. **Validates** the manifest against the protocol schema  
4. **Registers** the entry in the appropriate registry location

Submit via the auto-generated issue templates:
- [A2A AgentCard submission](.github/ISSUE_TEMPLATE/a2a-registry-submission.md)
- [MCP Server submission](.github/ISSUE_TEMPLATE/mcp-registry-submission.md)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes (models, configs, etc.)
4. The automated validation will check your changes
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on adding new models.

### Examples

Check out the [examples/](examples/) directory for:
- Complete example of adding a new protocol model
- Step-by-step walkthrough with the "Code Assistance Protocol"
- Best practices and common troubleshooting tips

## Workflows### For New Models1. **PR Validation** ([`.github/workflows/pr-model-validation.yml`](.github/workflows/pr-model-validation.yml)): Validates new models in pull requests2. **Schema Building** ([`.github/workflows/build-schemas.yml`](.github/workflows/build-schemas.yml)): Regenerates schemas when models change### For Registry Submissions- **A2A Issues** ([`.github/workflows/issues-a2a.yml`](.github/workflows/issues-a2a.yml)): Processes A2A AgentCard submissions- **MCP Issues** ([`.github/workflows/issues-mcp.yml`](.github/workflows/issues-mcp.yml)): Processes MCP server submissions### For Static Site Deployment1. **Build Static Content** ([`.github/workflows/build-static.yml`](.github/workflows/build-static.yml)): Builds registry data and creates static-site branch2. **Deploy to Azure Static Web Apps** ([`.github/workflows/deploy-azure-static.yml`](.github/workflows/deploy-azure-static.yml)): Deploys to Azure Static Web Apps3. **Deploy to Azure Web Sites** ([`.github/workflows/deploy-azure-websitesapi.yml`](.github/workflows/deploy-azure-websitesapi.yml)): Deploys registry API to Azure App Service with IIS web.config support## Deployment OptionsThe unified xRegistry AI supports multiple deployment options:### ⚡ Azure Static Web Apps- **Setup**: Add `AZURE_STATIC_WEB_APPS_API_TOKEN` secret- **Features**: Azure CDN, custom domains, staging environments- **URL**: Auto-generated by Azure or custom domain### 🌐 Azure Web Sites (App Service)- **Setup**: Add `AZURE_WEBAPP_PUBLISH_PROFILE` or Service Principal credentials- **Features**: Full .NET Core app with web.config URL rewriting for IIS compatibility- **URL**: `https://your-app.azurewebsites.net/api/registry/`- **Special**: Post-processed with `azure-webapi-postprocess.mjs` for proper IIS routing

## License

This project follows the same license as the xRegistry specification.

## Links

- [xRegistry Specification](https://github.com/xregistry/spec)
- [A2A Protocol Documentation](https://developers.google.com/agent-to-agent)
- [MCP Protocol Documentation](https://modelcontextprotocol.io) 