<img src="https://github.com/cncf/artwork/raw/main/projects/xregistry/horizontal/color/xregistry-horizontal-color.svg" alt="xRegistry" style="max-height: 30px;">

# xRegistry for AI

Automated registry for AI protocol metadata with issue-driven submissions and static site deployment.

## What This Repository Does

### 🎫 Issue-Driven Registration
Submit AI protocol implementations through GitHub issues:
- **Agent-to-Agent (A2A)** registrations via A2A issue template
- **Model Context Protocol (MCP)** registrations via MCP issue template  
- Automated validation and ingestion from remote repositories

### 🔄 Automated Workflows
- **Issue Processing**: Validates submissions and fetches metadata from remote repos
- **Schema Generation**: Auto-generates unified OpenAPI, JSON Schema, and Avro schemas
- **Static Site Build**: Packages registry data into deployable static site
- **Azure Deployment**: Deploys to Azure Static Web Apps with Angular SPA

### 📡 Deployed Services

#### Live Registry Site
- **Primary**: [xregistry-ai.azurestaticapps.net](https://xregistry-ai.azurestaticapps.net) (Azure Static Web Apps)
- **GitHub Pages**: [clemensv.github.io/xregistry-ai](https://clemensv.github.io/xregistry-ai)

#### API Endpoints
- `/registry/` - Browse all registered protocols
- `/registry/mcpproviders/` - MCP server implementations  
- `/registry/agentcardproviders/` - A2A agent implementations
- `/openapi/openapi.json` - Unified OpenAPI specification
- `/schema/json-schema.json` - Unified JSON Schema
- `/schema/avro-schema.json` - Unified Avro Schema

#### Search Indices
- `/flex.json` files for protocol-specific search
- Full-text search across all registered implementations

## Quick Start

### Submit Your Protocol Implementation
1. Ensure your repo has the required metadata file (`mcp.json` or `agent.json`)
2. Open an issue using the appropriate template
3. Automated validation will check your submission
4. Upon approval, your implementation is added to the registry

### Local Development
```bash
git clone <repository-url>
cd xregistry-ai
pip install -r requirements.txt
cd xreg && ./build-all.sh
```

## Supported Protocols
- **MCP (Model Context Protocol)**: Server implementations with `mcp.json`
- **A2A (Agent-to-Agent)**: Agent cards with `agent.json`
- **Extensible**: Add new protocols via model definitions

## Architecture
- **Registry Backend**: Custom xRegistry server (containerized)
- **Frontend**: Angular SPA (xregistry-viewer)
- **Deployment**: Azure Static Web Apps + GitHub Actions
- **Search**: Flex search indices with full-text capabilities 