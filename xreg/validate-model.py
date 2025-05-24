#!/usr/bin/env python3
"""
Standalone model validation script for xRegistry AI.
Can be used to validate new models before submitting PRs.
"""

import argparse
import json
import sys
from pathlib import Path

def validate_json_syntax(file_path):
    """Validate that a file contains valid JSON."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            json.load(f)
        return True, None
    except json.JSONDecodeError as e:
        return False, f"JSON syntax error: {e}"
    except Exception as e:
        return False, f"Error reading file: {e}"

def validate_model_structure(model_data, model_name):
    """Validate the structure of a model definition."""
    errors = []
    
    # Check for required top-level fields
    if 'groups' not in model_data:
        errors.append("Missing required 'groups' field")
        return errors
    
    if not isinstance(model_data['groups'], dict):
        errors.append("'groups' must be an object")
        return errors
    
    if len(model_data['groups']) == 0:
        errors.append("'groups' cannot be empty")
        return errors
    
    # Validate each group
    for group_name, group_data in model_data['groups'].items():
        if not isinstance(group_data, dict):
            errors.append(f"Group '{group_name}' must be an object")
            continue
        
        # Check required group fields
        required_group_fields = ['singular', 'plural']
        for field in required_group_fields:
            if field not in group_data:
                errors.append(f"Group '{group_name}' missing required field '{field}'")
        
        # Validate resources if present
        if 'resources' in group_data:
            if not isinstance(group_data['resources'], dict):
                errors.append(f"Group '{group_name}' resources must be an object")
                continue
            
            for resource_name, resource_data in group_data['resources'].items():
                if not isinstance(resource_data, dict):
                    errors.append(f"Resource '{group_name}.{resource_name}' must be an object")
                    continue
                
                # Check required resource fields
                required_resource_fields = ['singular', 'plural']
                for field in required_resource_fields:
                    if field not in resource_data:
                        errors.append(f"Resource '{group_name}.{resource_name}' missing required field '{field}'")
    
    return errors

def validate_config_consistency(config_data, model_name, model_data):
    """Validate that registry config is consistent with model definition."""
    errors = []
    
    if 'models' not in config_data:
        errors.append("Registry config missing 'models' section")
        return errors
    
    if model_name not in config_data['models']:
        errors.append(f"Model '{model_name}' not found in registry config")
        return errors
    
    model_config = config_data['models'][model_name]
    
    # Check required config fields
    required_fields = [
        'name', 'groupSingular', 'groupPlural', 
        'resourceSingular', 'resourcePlural', 'manifestFile'
    ]
    
    for field in required_fields:
        if field not in model_config:
            errors.append(f"Model config '{model_name}' missing required field '{field}'")
    
    # Validate consistency with model definition
    if 'groups' in model_data and model_data['groups']:
        # Get the first group (assuming single group per model for now)
        first_group_name, first_group = next(iter(model_data['groups'].items()))
        
        if 'groupSingular' in model_config and model_config['groupSingular'] != first_group.get('singular'):
            errors.append(f"Config groupSingular '{model_config['groupSingular']}' doesn't match model '{first_group.get('singular')}'")
        
        if 'groupPlural' in model_config and model_config['groupPlural'] != first_group.get('plural'):
            errors.append(f"Config groupPlural '{model_config['groupPlural']}' doesn't match model '{first_group.get('plural')}'")
        
        # Check resource consistency
        if 'resources' in first_group and first_group['resources']:
            first_resource_name, first_resource = next(iter(first_group['resources'].items()))
            
            if 'resourceSingular' in model_config and model_config['resourceSingular'] != first_resource.get('singular'):
                errors.append(f"Config resourceSingular '{model_config['resourceSingular']}' doesn't match model '{first_resource.get('singular')}'")
            
            if 'resourcePlural' in model_config and model_config['resourcePlural'] != first_resource.get('plural'):
                errors.append(f"Config resourcePlural '{model_config['resourcePlural']}' doesn't match model '{first_resource.get('plural')}'")
    
    return errors

def test_schema_generation(model_name):
    """Test that schema generation works with the new model."""
    try:
        import subprocess
        result = subprocess.run([
            'python', 'schema-generator.py', '--models', model_name, '--type', 'json-schema'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            return True, None
        else:
            return False, f"Schema generation failed: {result.stderr}"
    except subprocess.TimeoutExpired:
        return False, "Schema generation timed out"
    except Exception as e:
        return False, f"Error running schema generation: {e}"

def main():
    parser = argparse.ArgumentParser(description='Validate xRegistry AI model definitions')
    parser.add_argument('model_name', help='Name of the model to validate')
    parser.add_argument('--config-only', action='store_true', help='Only validate registry config')
    parser.add_argument('--no-schema-test', action='store_true', help='Skip schema generation test')
    
    args = parser.parse_args()
    
    model_name = args.model_name
    model_file = Path(f'../models/{model_name}/model.json')
    config_file = Path('registry-config.json')
    
    print(f"Validating model: {model_name}")
    print("=" * 50)
    
    errors = []
    warnings = []
    
    # Validate registry config
    print("1. Validating registry configuration...")
    if not config_file.exists():
        errors.append("Registry config file not found: registry-config.json")
    else:
        valid, error = validate_json_syntax(config_file)
        if not valid:
            errors.append(f"Registry config: {error}")
        else:
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    config_data = json.load(f)
                print("   ✅ Registry config JSON syntax valid")
                
                # Basic structure validation
                required_sections = ['registry', 'models', 'validationRules']
                for section in required_sections:
                    if section not in config_data:
                        errors.append(f"Registry config missing required section: {section}")
                
                if not errors:
                    print("   ✅ Registry config structure valid")
            except Exception as e:
                errors.append(f"Error loading registry config: {e}")
    
    if args.config_only:
        if errors:
            print("\n❌ Validation failed:")
            for error in errors:
                print(f"   - {error}")
            return 1
        else:
            print("\n✅ Registry config validation passed!")
            return 0
    
    # Validate model file
    print("\n2. Validating model file...")
    if not model_file.exists():
        errors.append(f"Model file not found: {model_file}")
    else:
        valid, error = validate_json_syntax(model_file)
        if not valid:
            errors.append(f"Model file: {error}")
        else:
            try:
                with open(model_file, 'r', encoding='utf-8') as f:
                    model_data = json.load(f)
                print("   ✅ Model JSON syntax valid")
                
                # Structure validation
                structure_errors = validate_model_structure(model_data, model_name)
                if structure_errors:
                    errors.extend([f"Model structure: {e}" for e in structure_errors])
                else:
                    print("   ✅ Model structure valid")
                
                # Config consistency check
                if config_file.exists() and 'config_data' in locals():
                    consistency_errors = validate_config_consistency(config_data, model_name, model_data)
                    if consistency_errors:
                        errors.extend([f"Config consistency: {e}" for e in consistency_errors])
                    else:
                        print("   ✅ Config consistency valid")
                        
            except Exception as e:
                errors.append(f"Error loading model file: {e}")
    
    # Test schema generation
    if not args.no_schema_test and not errors:
        print("\n3. Testing schema generation...")
        success, error = test_schema_generation(model_name)
        if success:
            print("   ✅ Schema generation test passed")
        else:
            warnings.append(f"Schema generation test: {error}")
    
    # Summary
    print("\n" + "=" * 50)
    if errors:
        print("❌ Validation failed:")
        for error in errors:
            print(f"   - {error}")
        return 1
    else:
        print("✅ Model validation passed!")
        if warnings:
            print("\n⚠️  Warnings:")
            for warning in warnings:
                print(f"   - {warning}")
        
        print(f"\nNext steps:")
        print(f"1. Add/update registry config for '{model_name}' in registry-config.json")
        print(f"2. Test locally: python schema-generator.py --models {model_name} --type json-schema")
        print(f"3. Submit PR with both model.json and registry-config.json changes")
        return 0

if __name__ == '__main__':
    sys.exit(main()) 