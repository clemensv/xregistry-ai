#!/usr/bin/env python3

import json
import os
import sys
from pathlib import Path

def load_config():
    """Load the registry configuration."""
    config_path = Path(__file__).parent / "registry-config.json"
    with open(config_path) as f:
        return json.load(f)

def generate_issue_template(model_name, model_config, validation_rules):
    """Generate a GitHub issue template for a specific model."""
    
    template = f"""---
name: {model_config['issueTitle']}
about: {model_config['issueAbout']}
title: ''
labels: '{model_name}'
assignees: ''

---

<!--
To add entries into this registry, you need to fill out the section enclosed by ~~~ below. 

Using this form requires that your {model_config['name']} {model_config['resourceSingular'].title()} resides in a publicly accessible
Git repository and that the given path contains a valid {model_config['manifestFile']} manifest
that describes the {model_config['resourceSingular']}.

When you submit the issue, the repository will be inspected, the {model_config['manifestFile']}
file will be sourced from the given location and copied into this registry.

The file will be registered at /{model_config['groupPlural']}/{{{model_config['groupSingular']}}}/{model_config['resourcePlural']}/{{{model_config['resourceSingular']}}}.

If the {model_config['groupSingular']} name and {model_config['resourceSingular']} name are already taken, the request will be rejected.

- repo: Path to the repo (e.g. org/repo) on Github or an absolute URL to a Git repo elsewhere
- path: Path (folder) in the repo where the `{model_config['manifestFile']}` file can be found
- branch: Branch of the repo to look up
- {model_config['groupSingular']}: The name of the {model_config['groupSingular']} group to put the registration into. 
{'                     You or your company are the provider.' if 'provider' in model_config['groupSingular'] else ''}
- {model_config['resourceSingular']}: Identifier of the {model_config['resourceSingular']} to register. 

The {model_config['groupSingular']} and {model_config['resourceSingular']} values must conform to this rule:

{validation_rules['nameDescription']}

!-->

~~~
repo: <repo>
path: <path>
branch: <branch>
{model_config['groupSingular']}: <the {model_config['groupSingular']} group in the registry>
{model_config['resourceSingular']}: <the {model_config['resourceSingular']} name in the registry>
~~~

"""
    return template

def generate_workflow_template(model_name, model_config):
    """Generate a GitHub Actions workflow for processing issues for a specific model."""
    
    workflow = f"""name: Ingest {model_config['name']} from remote repo via issue
on:
  issues:
    types: [opened, edited]

jobs:
  validate-{model_name}:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      contents: write
    steps:
      - name: Checkout repo (needed for node_modules)
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          npm install js-yaml axios @octokit/rest minimist

      - name: Validate issue YAML and check submission file
        env:
          GH_TOKEN: ${{{{ secrets.GITHUB_TOKEN }}}}
        run: |
          node .github/scripts/validate-submission.js -gs {model_config['groupSingular']} -gp {model_config['groupPlural']} -rs {model_config['resourceSingular']} -rp {model_config['resourcePlural']} -f {model_config['manifestFile']}{' -d' if model_config.get('hasDocument', False) else ''}
"""
    return workflow

def main():
    """Main function to generate all issue templates and workflows."""
    
    # Load configuration
    config = load_config()
    
    # Get paths
    repo_root = Path(__file__).parent.parent
    issue_template_dir = repo_root / ".github" / "ISSUE_TEMPLATE"
    workflow_dir = repo_root / ".github" / "workflows"
    
    # Ensure directories exist
    issue_template_dir.mkdir(parents=True, exist_ok=True)
    workflow_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Generating issue templates and workflows for {config['registry']['name']}...")
    
    # Generate templates for each model
    for model_name, model_config in config['models'].items():
        print(f"  Generating for {model_config['name']} ({model_name})...")
        
        # Generate issue template
        issue_template = generate_issue_template(model_name, model_config, config['validationRules'])
        issue_file = issue_template_dir / f"{model_name}-registry-submission.md"
        
        with open(issue_file, 'w') as f:
            f.write(issue_template)
        print(f"    Created issue template: {issue_file}")
        
        # Generate workflow
        workflow_template = generate_workflow_template(model_name, model_config)
        workflow_file = workflow_dir / f"issues-{model_name}.yml"
        
        with open(workflow_file, 'w') as f:
            f.write(workflow_template)
        print(f"    Created workflow: {workflow_file}")
    
    print("Issue template and workflow generation completed!")
    
    # Also generate a combined validation script
    generate_validation_script(config, repo_root)

def generate_validation_script(config, repo_root):
    """Generate the unified validation script."""
    
    models_json = json.dumps(config['models'], indent=2)
    validation_rules_json = json.dumps(config['validationRules'], indent=2)
    
    script_content = f"""/**
 * Unified validation script for {config['registry']['name']} registry submissions.
 * Validates YAML in GitHub issue body or author comment and processes manifest files.
 * Requires env: GH_TOKEN
 */
const {{ Octokit }} = require("@octokit/rest");
const axios = require("axios");
const yaml = require("js-yaml");
const fs = require("fs");
const os = require("os");
const pathModule = require("path");
const {{ execSync, rmSync }} = require("child_process");
const args = require("minimist")(process.argv.slice(2));

// Model configuration
const MODELS = {models_json};

const VALIDATION_RULES = {validation_rules_json};

const groupSingular = args.gs;
const groupPlural = args.gp;
const resourceSingular = args.rs;
const resourcePlural = args.rp;
const fileName = args.f;
const hasDocument = args.d || false;

if (
  !groupSingular ||
  !groupPlural ||
  !resourceSingular ||
  !resourcePlural ||
  !fileName
) {{
  console.error(
    "❌ Missing required arguments. Please provide -gs, -gp, -rs, -rp, and -f."
  );
  process.exit(1);
}}

// Find the model configuration for these parameters
let currentModel = null;
for (const [modelName, modelConfig] of Object.entries(MODELS)) {{
  if (modelConfig.groupSingular === groupSingular && 
      modelConfig.groupPlural === groupPlural &&
      modelConfig.resourceSingular === resourceSingular &&
      modelConfig.resourcePlural === resourcePlural &&
      modelConfig.manifestFile === fileName) {{
    currentModel = {{ name: modelName, config: modelConfig }};
    break;
  }}
}}

if (!currentModel) {{
  console.error("❌ Could not find model configuration for provided parameters.");
  process.exit(1);
}}

const octokit = new Octokit({{ auth: process.env.GH_TOKEN }});

(async () => {{
  const [owner, repo] = process.env.GITHUB_REPOSITORY.split("/");
  const ghOwner = owner;
  const ghRepo = repo;

  const event = JSON.parse(
    fs.readFileSync(process.env.GITHUB_EVENT_PATH, "utf8")
  );
  const issue_number = event.issue?.number;

  if (!issue_number) {{
    console.error("❌ Could not determine issue number.");
    process.exit(1);
  }}

  const {{ data: issue }} = await octokit.rest.issues.get({{
    owner,
    repo,
    issue_number,
  }});
  const issueAuthor = issue.user.login;

  const extractYamlBlock = (text) => {{
    if (!text) return null;
    const patterns = [
      /```(?:yaml)?\\s*([\\s\\S]+?)```/i,
      /~~~(?:yaml)?\\s*([\\s\\S]+?)~~~/i,
      /---\\s*([\\s\\S]+?)---/i,
    ];
    for (const pattern of patterns) {{
      const match = text.match(pattern);
      if (match) return match[1];
    }}
    return null;
  }};

  let yamlSource = extractYamlBlock(issue.body);
  if (!yamlSource) {{
    const comments = await octokit.paginate(octokit.rest.issues.listComments, {{
      owner,
      repo,
      issue_number,
    }});
    for (const comment of comments) {{
      if (comment.user.login === issueAuthor) {{
        yamlSource = extractYamlBlock(comment.body);
        if (yamlSource) break;
      }}
    }}
  }}

  if (!yamlSource) {{
    await octokit.rest.issues.createComment({{
      owner,
      repo,
      issue_number,
      body: "❌ No valid YAML block found in the issue body or comments by the author.",
    }});
    process.exit(0);
  }}

  let config;
  try {{
    config = yaml.load(yamlSource);
  }} catch (err) {{
    await octokit.rest.issues.createComment({{
      owner,
      repo,
      issue_number,
      body: `❌ YAML parsing error: \\`${{err.message}}\\``,
    }});
    process.exit(0);
  }}

  const {{
    repo: repoUrl,
    path = "",
    branch: externalBranch = "main",
    [groupSingular]: groupName = "",
    [resourceSingular]: resourceName = "",
  }} = config;

  // RFC3986 unreserved + "@" validation
  const VALID_NAME_REGEX = new RegExp(VALIDATION_RULES.nameRegex);

  if (!repoUrl || !groupName || !resourceName) {{
    await octokit.rest.issues.createComment({{
      owner,
      repo,
      issue_number,
      body: `❌ YAML must contain non-empty 'repo:', '${{groupSingular}}:', and '${{resourceSingular}}:' fields.`,
    }});
    process.exit(0);
  }}

  if (!VALID_NAME_REGEX.test(groupName)) {{
    await octokit.rest.issues.createComment({{
      owner,
      repo,
      issue_number,
      body: `❌ Invalid \\`${{groupSingular}}:\\` value: \\`${{groupName}}\\`. ${{VALIDATION_RULES.nameDescription}}`,
    }});
    process.exit(0);
  }}

  if (!VALID_NAME_REGEX.test(resourceName)) {{
    await octokit.rest.issues.createComment({{
      owner,
      repo,
      issue_number,
      body: `❌ Invalid \\`${{resourceSingular}}:\\` value: \\`${{resourceName}}\\`. ${{VALIDATION_RULES.nameDescription}}`,
    }});
    process.exit(0);
  }}

  console.log(`✅ Processing ${{currentModel.config.name}} submission: ${{groupName}}/${{resourceName}}`);
  
  // TODO: Add the rest of the validation logic from the original script
  // This would include file fetching, validation, and registry update
  
    await octokit.rest.issues.createComment({{    owner,    repo,    issue_number,    body: `✅ ${{currentModel.config.name}} submission validated successfully! Processing ${{groupName}}/${{resourceName}}...`,  }});}})();"""        script_file = repo_root / ".github" / "scripts" / "validate-submission.js"    script_file.parent.mkdir(parents=True, exist_ok=True)        with open(script_file, 'w', encoding='utf-8') as f:        f.write(script_content)        print(f"    Created unified validation script: {script_file}")if __name__ == "__main__":    main() 