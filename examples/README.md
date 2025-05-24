# Examples

This directory contains examples demonstrating how to add new AI protocol models to the xRegistry AI system.

## Example: Adding Code Assistance Protocol (CAP)

This example shows how to add a fictional "Code Assistance Protocol" to demonstrate the complete process.

### Files in this Example

- [`example-new-model/model.json`](example-new-model/model.json) - Complete model definition
- [`example-registry-config-addition.json`](example-registry-config-addition.json) - Registry configuration entry

### Step-by-Step Process

1. **Create the Model Directory**
   ```bash
   mkdir models/code-assistance
   ```

2. **Add the Model Definition**
   Copy `example-new-model/model.json` to `models/code-assistance/model.json`

3. **Update Registry Configuration**
   Add the entry from `example-registry-config-addition.json` to the `models` section of `xreg/registry-config.json`

4. **Validate Locally**
   ```bash
   cd xreg
   python validate-model.py code-assistance
   ```

5. **Test Schema Generation**
   ```bash
   python schema-generator.py --list
   python schema-generator.py --models code-assistance --type json-schema
   ```

6. **Submit Pull Request**
   Create a PR with:
   - `models/code-assistance/model.json`
   - Updated `xreg/registry-config.json`

### What the Validation System Will Do

When you submit the PR, the automated validation will:

✅ **Detect the new model** (`code-assistance`)  
✅ **Validate JSON syntax** in both files  
✅ **Check model structure** (required fields, proper nesting)  
✅ **Test schema generation** with the new model included  
✅ **Verify config consistency** between model.json and registry-config.json  
✅ **Generate issue templates** for the new protocol  
✅ **Create GitHub Actions workflows** for submission processing  

### After the PR is Merged

The system will automatically:

1. **Generate unified schemas** including the CAP model
2. **Create issue template**: `.github/ISSUE_TEMPLATE/code-assistance-registry-submission.md`
3. **Create workflow**: `.github/workflows/issues-code-assistance.yml`
4. **Update CLI**: `python schema-generator.py --list` will show `code-assistance`
5. **Generate API endpoints** for CAP in the OpenAPI specification

### Example Generated Issue Template

The system would generate something like:

```markdown
---
name: Registry submission for Code Assistance Protocol
about: File this issue when you want to add a new Code Assistant to the registry
title: ''
labels: 'code-assistance'
assignees: ''
---

~~~
repo: <repo>
path: <path>
branch: <branch>
codeassistanceprovider: <the provider group in the registry>
assistant: <the assistant name in the registry>
~~~
```

### Example API Endpoints

The generated OpenAPI spec would include endpoints like:

```
GET /codeassistanceproviders
POST /codeassistanceproviders
GET /codeassistanceproviders/{providerid}
GET /codeassistanceproviders/{providerid}/assistants
POST /codeassistanceproviders/{providerid}/assistants
GET /codeassistanceproviders/{providerid}/assistants/{assistantid}
```

## Model Design Best Practices

Based on this example, here are best practices for designing new models:

### 1. Follow Naming Conventions
- **Group names**: `{protocol}providers` (e.g., `codeassistanceproviders`)
- **Resource names**: Descriptive and clear (e.g., `assistants`)
- **Attributes**: Use clear, documented names

### 2. Include Rich Metadata
- Add descriptions for all groups, resources, and attributes
- Use appropriate data types (`string`, `array`, `object`, `url`, etc.)
- Mark required fields appropriately
- Provide default values where sensible

### 3. Design for Extensibility
- Use nested objects for complex configuration
- Include arrays for multiple items (languages, capabilities, etc.)
- Plan for future attributes by using flexible schemas

### 4. Document Everything
- Every attribute should have a description
- Use clear, consistent language
- Explain the purpose and expected values

### 5. Test Thoroughly
- Validate your model with `python validate-model.py`
- Test schema generation
- Verify the generated templates make sense

## Testing Your Model

Before submitting a PR, use these commands to test your model:

```bash
cd xreg

# Validate structure and consistency
python validate-model.py your-model-name

# Test schema generation
python schema-generator.py --models your-model-name --type json-schema
python schema-generator.py --models your-model-name --type openapi

# Test with all models together
python schema-generator.py --models --type json-schema

# Generate issue templates
python generate-issue-templates.py
```

## Common Issues and Solutions

### Model Validation Fails
- Check JSON syntax with a JSON validator
- Ensure all required fields (`groups`, `singular`, `plural`) are present
- Verify nested structure is correct

### Config Consistency Errors
- Make sure `groupSingular`/`groupPlural` match your model's group definition
- Verify `resourceSingular`/`resourcePlural` match your resource definition
- Check that the model name in config matches your directory name

### Schema Generation Fails
- Test with just your model first: `--models your-model-name`
- Check for circular references or invalid type definitions
- Ensure all referenced types are defined

## Need Help?

1. Check existing models in `models/` for reference
2. Review the validation output for specific error messages
3. Read the [Contributing Guide](../CONTRIBUTING.md)
4. Open an issue for guidance

The automated validation system will provide detailed feedback on any issues! 