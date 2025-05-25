import argparse
import copy
import json
import os
import re
import glob
from pathlib import Path
from jsonpointer import resolve_pointer

avro_generic_record_name = "GenericRecord"
avro_generic_record = {
  "type": "record",
  "name": avro_generic_record_name,
  "fields": [
    {
      "name": "object",
      "type": {
        "type": "map",
        "values": [
          "null",
          "boolean",
          "int",
          "long",
          "float",
          "double",
          "bytes",
          "string",
          {
            "type": "array",
            "items": [
              "null",
              "boolean",
              "int",
              "long",
              "float",
              "double",
              "bytes",
              "string",
              avro_generic_record_name
            ]
          },
          avro_generic_record_name
        ]
      }
    }
  ]
}

avro_type_mapping = {
    "string": {"type": "string"},
    "object": {"type": "record"},
    "map": {"type": { "type": "map"}},
    "uri": {"type": "string"},
    "url": {"type": "string"},
    "datetime": {"type": {"type":"int", "logicalType": "time-millis"}},
    "integer": {"type": "int"},
    "uinteger": {"type": "int"},
    "boolean": {"type": "boolean"},
    "array": {"type":{"type": "array", "items": ""}},
    "uritemplate": {"type": "string"},
    "binary": {"type": "bytes"},
    "timestamp": {"type": {"type":"int", "logicalType": "timestamp-millis"}},
    "any": avro_generic_record,
    "var": avro_generic_record,
    "xid": {"type": "string"}
}

json_type_mapping = {
    "string": {"type": "string"},
    "object": {"type": "object"},
    "map": {"type": "object"},
    "uri": {"type": "string", "format": "uri"},
    "url": {"type": "string", "format": "uri"},
    "xid": {"type": "string", "format": "uri"},
    "datetime": {"type": "string", "format": "date-time"},
    "integer": {"type": "integer"},
    "uinteger": {"type": "integer", "minimum": 0},
    "boolean": {"type": "boolean"},
    "array": {"type": "array"},
    "uritemplate": {"type": "string", "format": "uri-template"},
    "binary": {"type": "string", "format": "base64"},
    "timestamp": {"type": "string", "format": "date-time"},
    "any": {"type": "object"},
    "var": {"type": "object"}
}

json_common_attributes = {
    "name": {"type": "string", "description": "Name of the object"},
    "epoch": {"type": "integer", "description": "Epoch time of the object creation"},
    "self": {"type": "string", "format": "uri", "description": "URL of the object"},
    "xid": {"type": "string", "format": "xid", "description": "Relative URL of the object"},
    "description": {"type": "string", "description": "Description of the object"},
    "documentation": {"type": "string", "format": "uri", "description": "URI of the documentation of the object"},
    "labels": {"type": "object", "description": "Labels for the object"},
    "createdat": {"type": "string", "format": "date-time", "description": "Time of the object creation"},
    "modifiedat": {"type": "string", "format": "date-time", "description": "Time of the object modification"}
}

avro_common_attributes = [
    {"name": "name", "type": ["string", "null"], "doc": "Name of the object"},
    {"name": "epoch", "type": ["int", "null"], "doc": "Epoch time of the object creation"},
    {"name": "self", "type": "string", "doc": "URL of the object"},
    {"name": "xid", "type": "string", "doc": "XID of the object"},
    {"name": "description", "type": ["string", "null"], "doc": "Description of the object"},
    {"name": "documentation", "type": ["string", "null"], "doc": "URI of the documentation of the object"},
    {"name": "labels", "type": { "type": "map", "values": ["string", "null"]} , "doc": "Labels for the object"},
    {"name": "createdat", "type": [{"type":"int", "logicalType": "time-millis"}, "null"], "doc": "Time of the object creation"},
    {"name": "modifiedat", "type": [{"type":"int", "logicalType": "time-millis"},"null"], "doc": "Time of the object modification"}
]

def pascal(string):
    if not string or len(string) == 0:
        return string
    words = []
    if '_' in string:
        # snake_case
        words = re.split(r'_', string)
    elif '-' in string:
        # dash-case
        words = re.split(r'-', string)
    elif string[0].isupper():
        # PascalCase
        words = re.findall(r'[A-Z][a-z0-9_]*\.?', string)
    else:
        # camelCase
        words = re.findall(r'[a-z]+\.?|[A-Z][a-z0-9_]*\.?', string)
    result = ''.join(word.capitalize() for word in words)
    return result

def camel(string):
    pascalString = pascal(string)
    return pascalString[0:1].lower() + pascalString[1:]

def discover_models(base_dir=None):
    """Discover all model files in the models directory."""
    if base_dir is None:
        base_dir = os.path.dirname(os.path.abspath(__file__))
    
    models_dir = os.path.join(base_dir, '..', 'models')
    models = {}
    
    if os.path.exists(models_dir):
        for model_dir in os.listdir(models_dir):
            model_path = os.path.join(models_dir, model_dir)
            if os.path.isdir(model_path):
                model_file = os.path.join(model_path, 'model.json')
                if os.path.exists(model_file):
                    models[model_dir] = model_file
    
    return models

def list_models():
    """List all available models."""
    models = discover_models()
    if models:
        print("Available models:")
        for model_name, model_path in models.items():
            print(f"  {model_name}: {model_path}")
    else:
        print("No models found in models directory.")
    return models

def generate_openapi(model_definition):
    # now recursively find all $ref attributes in the template and replace them with references to the appropriate schema
    def replace_refs(schema_fragment: dict, expression: str, reference: str):
        for k,v in schema_fragment.items():
            if k == "$ref":
                if expression in v:
                    schema_fragment[k] = v.replace(expression, reference)
            if isinstance(v, dict):
                replace_refs(v, expression, reference)
            elif isinstance(v, list):
                for item in v:
                    if isinstance(item, dict):
                        replace_refs(item, expression, reference)

    def replace_ops(schema_fragment: dict, expression: str, reference: str):
        for k,v in schema_fragment.items():
            if k == "operationId":
                if v.find(expression) != -1:
                    schema_fragment[k] = v.replace(expression, reference)
            if isinstance(v, dict):
                replace_ops(v, expression, reference)
            elif isinstance(v, list):
                for item in v:
                    if isinstance(item, dict):
                        replace_ops(item, expression, reference)

    try:
        template_file_name = os.path.join(os.path.dirname(__file__), '.xregistry-spec', 'core', 'templates', 'xregistry_openapi_template.json')
        with open(template_file_name) as file:
            openapi = json.load(file)
        json_schema = generate_json_schema(model_definition, True)
        # merge JSON schema with template
        for schema_name, schema in json_schema["components"]["schemas"].items():
            openapi["components"]["schemas"][schema_name] = schema
        # do the fixups

        path = "/"
        root_template = openapi["paths"][path]
        replace_refs(root_template, "{%-documentTypeReference-%}", f"#/components/schemas/document")

        path = "/{%-groupNamePlural-%}"
        path_template = openapi["paths"][path]
        for _, group in model_definition.get("groups", {}).items():
            path_template_copy = copy.deepcopy(path_template)
            replace_refs(path_template_copy, "{%-groupTypeReference-%}", f"#/components/schemas/{group['singular']}")
            replace_ops(path_template_copy, "{%-groupNamePlural-%}", f"{pascal(group['plural'])}")
            openapi["paths"][f"/{group['plural']}"] = path_template_copy
        openapi["paths"].pop(path)

        path = "/{%-groupNamePlural-%}/{groupid}"
        group_template = openapi["paths"][path]
        for _, group in model_definition.get("groups", {}).items():
            group_template_copy = copy.deepcopy(group_template)
            replace_refs(group_template_copy, "{%-groupTypeReference-%}", f"#/components/schemas/{group['singular']}")
            replace_ops(group_template_copy, "{%-groupNameSingular-%}", f"{pascal(group['singular'])}")
            openapi["paths"][f"/{group['plural']}/{{groupid}}"] = group_template_copy

        openapi["paths"].pop(path)
        path = "/{%-groupNamePlural-%}/{groupid}/{%-resourceNamePlural-%}"
        resource_template = openapi["paths"][path]
        for _, group in model_definition.get("groups", {}).items():
            for _, resource in group.get("resources", {}).items():
                resource = resolve_resource(group, resource)
                resource_template_copy = copy.deepcopy(resource_template)
                replace_refs(resource_template_copy, "{%-resourceTypeReference-%}", f"#/components/schemas/{resource['singular']}")
                replace_ops(resource_template_copy, "{%-resourceNamePlural-%}", f"{pascal(resource['plural'])}")
                openapi["paths"][f"/{group['plural']}/{{groupid}}/{resource['plural']}"] = resource_template_copy

        openapi["paths"].pop(path)

        path = "/{%-groupNamePlural-%}/{groupid}/{%-resourceNamePlural-%}/{resourceid}"
        resource_instance_template = openapi["paths"][path]
        for _, group in model_definition.get("groups", {}).items():
            for _, resource in group.get("resources", {}).items():
                resource = resolve_resource(group, resource)
                resource_instance_template_copy = copy.deepcopy(resource_instance_template)
                replace_refs(resource_instance_template_copy, "{%-resourceTypeReference-%}", f"#/components/schemas/{resource['singular']}")
                replace_ops(resource_instance_template_copy, "{%-resourceNameSingular-%}", f"{pascal(resource['singular'])}")
                openapi["paths"][f"/{group['plural']}/{{groupid}}/{resource['plural']}/{{resourceid}}"] = resource_instance_template_copy

        openapi["paths"].pop(path)

        return openapi
    except Exception as e:
        print(f"Warning: Could not load OpenAPI template: {e}")
        return {"openapi": "3.0.0", "info": {"title": "xRegistry API", "version": "1.0"}, "paths": {}}

def generate_json_schema(model_definition, for_openapi=False) -> dict:

    if for_openapi:
        root_schema = {"components": {"schemas": {}}}
        schemas = root_schema["components"]["schemas"]
    else:
        root_schema = {"$schema": "http://json-schema.org/draft-07/schema#", "$defs": {}}
        schemas = root_schema["$defs"]

    def handle_item(resource_schema, type, item):
        if type == "array":
            if item.get("type", "") == "object":
                items_schema = {"type": "object"}
                if "attributes" in item:
                    properties = {}
                    required = []
                    handle_attributes({"properties": properties, "required": required}, item["attributes"])
                    items_schema["properties"] = properties
                    if required:
                        items_schema["required"] = required
                resource_schema["items"] = items_schema
            else:
                item_type = item.get("type", "")
                if item_type in json_type_mapping:
                    resource_schema["items"] = json_type_mapping[item_type]
                else:
                    resource_schema["items"] = {"type": "string"}
        elif type == "map":
            if item.get("type", "") == "object":
                additional_properties_schema = {"type": "object"}
                if "attributes" in item:
                    properties = {}
                    required = []
                    handle_attributes({"properties": properties, "required": required}, item["attributes"])
                    additional_properties_schema["properties"] = properties
                    if required:
                        additional_properties_schema["required"] = required
                resource_schema["additionalProperties"] = additional_properties_schema
            else:
                item_type = item.get("type", "")
                if item_type in json_type_mapping:
                    resource_schema["additionalProperties"] = json_type_mapping[item_type]
                else:
                    resource_schema["additionalProperties"] = {"type": "string"}

    def handle_attributes(resource_schema, attributes):
        for attribute_name, attribute in attributes.items():
            attribute_type = attribute.get("type", "")
            if attribute_name == "*":
                resource_schema["additionalProperties"] = True
                continue

            # Get the JSON schema type mapping
            if attribute_type in json_type_mapping:
                attribute_schema = copy.deepcopy(json_type_mapping[attribute_type])
            else:
                attribute_schema = {"type": "string"}

            # Add description if available
            if "description" in attribute:
                attribute_schema["description"] = attribute["description"]

            # Handle enum
            if "enum" in attribute:
                attribute_schema["enum"] = attribute["enum"]

            # Handle default
            if "default" in attribute:
                attribute_schema["default"] = attribute["default"]

            # Handle object type with nested attributes
            if attribute_type == "object" and "attributes" in attribute:
                properties = {}
                required = []
                handle_attributes({"properties": properties, "required": required}, attribute["attributes"])
                attribute_schema["properties"] = properties
                if required:
                    attribute_schema["required"] = required

            # Handle array and map types with items
            if attribute_type in ["array", "map"] and "item" in attribute:
                handle_item(attribute_schema, attribute_type, attribute["item"])

            # Add to properties
            resource_schema["properties"][attribute_name] = attribute_schema

            # Handle required
            if attribute.get("required", False):
                resource_schema["required"].append(attribute_name)

    # Document schema
    document_schema = {"type": "object", "properties": copy.deepcopy(json_common_attributes), "required": []}
    document_properties = []

    for groups_name, group in model_definition.get("groups", {}).items():
        group_name = group["singular"]
        resource_collection_fields = []

        for resource_name, resource in group.get("resources", {}).items():
            resource = resolve_resource(group, resource)
            resource_properties = copy.deepcopy(json_common_attributes)
            resource_properties[resource_name + "id"] = {"type": "string", "description": f"ID of the {resource_name} object"}
            resource_required = []

            resource_schema = {"type": "object", "properties": resource_properties, "required": resource_required}
            attributes = resource.get("attributes", {})

            if resource.get("versions", 1) != 1:
                version_properties = copy.deepcopy(resource_properties)
                version_properties["versionid"] = {"type": "string", "description": f"ID of the {resource_name} version"}
                version_required = []
                version_schema = {"type": "object", "properties": version_properties, "required": version_required}
                handle_attributes(version_schema, attributes)
                schemas[pascal(resource_name) + "VersionType"] = version_schema

                versions_schema = {
                    "oneOf": [
                        {"type": "object", "additionalProperties": {"$ref": f"#/$defs/{pascal(resource_name)}VersionType" if not for_openapi else f"#/components/schemas/{pascal(resource_name)}VersionType"}},
                        {
                            "type": "object",
                            "properties": {
                                "versionsUrl": {"type": "string"},
                                "versionCount": {"type": "integer"}
                            },
                            "required": ["versionsUrl", "versionCount"]
                        }
                    ]
                }
                resource_schema["properties"]["versions"] = versions_schema
            else:
                handle_attributes(resource_schema, attributes)

            schemas[pascal(resource_name) + "Type"] = resource_schema

        group_properties = copy.deepcopy(json_common_attributes)
        group_properties[group_name + "id"] = {"type": "string", "description": f"ID of the {group_name} object"}
        group_required = []
        group_schema = {"type": "object", "properties": group_properties, "required": group_required}

        attributes = group.get("attributes", {})
        handle_attributes(group_schema, attributes)

        for resource_name, resource in group.get("resources", {}).items():
            resource = resolve_resource(group, resource)
            resource_collection_schema = {
                "type": "object",
                "additionalProperties": {"$ref": f"#/$defs/{pascal(resource['singular'])}Type" if not for_openapi else f"#/components/schemas/{pascal(resource['singular'])}Type"}
            }
            group_schema["properties"][camel(resource["plural"])] = resource_collection_schema

        schemas[pascal(group_name) + "Type"] = group_schema

        groups_schema = {
            "type": "object",
            "additionalProperties": {"$ref": f"#/$defs/{pascal(group_name)}Type" if not for_openapi else f"#/components/schemas/{pascal(group_name)}Type"}
        }
        document_schema["properties"][camel(groups_name)] = groups_schema

    schemas["document"] = document_schema

    return root_schema

def generate_avro_schema(model_definition) -> dict:
    record_types = set()

    def handle_item(resource_schema, type, item, name, prefix):
        if type == "array":
            if item.get("type", "") == "object":
                items_name = f"{prefix}{pascal(name)}Item"
                if items_name not in record_types:
                    record_types.add(items_name)
                    items_schema = {"type": "record", "name": items_name, "fields": []}
                    if "attributes" in item:
                        handle_attributes(items_schema, item["attributes"], prefix + pascal(name))
                    resource_schema["type"] = {"type": "array", "items": items_name}
                else:
                    resource_schema["type"] = {"type": "array", "items": items_name}
            else:
                item_type = item.get("type", "")
                if item_type in avro_type_mapping:
                    resource_schema["type"] = {"type": "array", "items": avro_type_mapping[item_type]["type"]}
                else:
                    resource_schema["type"] = {"type": "array", "items": "string"}

    def handle_attributes(resource_schema, attributes, type_prefix=""):
        for attribute_name, attribute in attributes.items():
            if attribute_name == "*":
                # For wildcard attributes, use a generic record
                resource_schema["fields"].append({
                    "name": "additionalProperties",
                    "type": avro_generic_record
                })
                continue

            attribute_type = attribute.get("type", "")
            field = {"name": attribute_name}

            if attribute_type in avro_type_mapping:
                if attribute_type == "object" and "attributes" in attribute:
                    object_name = f"{type_prefix}{pascal(attribute_name)}"
                    if object_name not in record_types:
                        record_types.add(object_name)
                        object_schema = {"type": "record", "name": object_name, "fields": []}
                        handle_attributes(object_schema, attribute["attributes"], type_prefix + pascal(attribute_name))
                        field["type"] = object_name
                    else:
                        field["type"] = object_name
                elif attribute_type in ["array", "map"] and "item" in attribute:
                    handle_item(field, attribute_type, attribute["item"], attribute_name, type_prefix)
                else:
                    field["type"] = avro_type_mapping[attribute_type]
            else:
                field["type"] = "string"

            if "description" in attribute:
                field["doc"] = attribute["description"]

            if "default" in attribute:
                field["default"] = attribute["default"]

            resource_schema["fields"].append(field)

    document_properties = []

    for groups_name, group in model_definition.get("groups", {}).items():
        group_name = group["singular"]
        resource_collection_fields = []

        for resource_name, resource in group.get("resources", {}).items():
            resource = resolve_resource(group, resource)

            if resource.get("versions", 1) != 1:
                record_types.add(resource_name)
                props = copy.deepcopy(avro_common_attributes)
                props.insert(0, {"name": resource_name+"id", "type": "string", "description": f"ID of the {resource_name} object"})
                resource_schema = {
                    "type": "record",
                    "name": pascal(resource_name)+"Type",
                    "fields": props
                }
                
                resource_version_schema = copy.deepcopy(resource_schema)
                resource_version_schema["fields"].insert(0, {"name" : "versionid", "type": "string", "description": f"ID of the {resource_name} version"})
                attributes = resource.get("attributes", {})
                handle_attributes(resource_version_schema, attributes, pascal(resource_name))
                resource_version_schema["name"] = pascal(resource_name)+"VersionType"
                
                resource_schema["fields"].append({
                    "name": "versions",
                    "type": [
                        {
                            "type": "map",
                            "values": resource_version_schema
                        },
                        {
                            "type": "record",
                            "name": pascal(resource_name)+"VersionInfo",
                            "fields": [
                                {
                                    "name": "versionsUrl",
                                    "type": "string"
                                },
                                {
                                    "name": "versionCount",
                                    "type": "int"
                                }
                            ]
                        }
                    ]
                })

                resource_collection_fields.append({
                    "name": camel(resource["plural"]),
                    "type" :{
                        "type": "map",
                        "values": pascal(resource_name)+"Type"
                    }
                    })
            else:
                record_types.add(resource_name)
                props = copy.deepcopy(avro_common_attributes)
                props.insert(0, {"name": resource_name+"id", "type": "string", "description": f"ID of the {resource_name} object"})
                resource_schema = {
                    "type": "record",
                    "name": pascal(resource_name)+"Type",
                    "fields": props
                }
                attributes = resource.get("attributes", {})
                handle_attributes(resource_schema, attributes)

                resource_collection_fields.append({
                    "name": camel(resource["plural"]),
                    "type" :{
                        "type": "map",
                        "values": resource_schema
                    }
                })

        props = copy.deepcopy(avro_common_attributes)
        props.insert(0, {"name" : group_name+"id", "type": "string", "description": f"ID of the {group_name} object"})
        group_schema = {
            "type": "record",
            "name": pascal(group_name)+"Type",
            "fields": props,
        }
        attributes = group.get("attributes", {})
        handle_attributes(group_schema, attributes)
        for resource_collection in resource_collection_fields:
            group_schema["fields"].append(resource_collection)
        groups_schema = {
            "name": camel(groups_name),
            "type": {
                "type": "map",
                "values": group_schema
            }
        }
        document_properties.append(groups_schema)

    document_type = {
        "type": "record",
        "name": "Document",
        "fields": copy.deepcopy(avro_common_attributes) + document_properties
    }

    return document_type

def resolve_resource(group, resource):
    if "uri" in resource:
        try:
            base_uri = group["$source"]
            file_uri = resource["uri"]

            # split off the JSON pointer part, if any
            if "#" in file_uri:
                file_uri, json_pointer = file_uri.split("#", 1)
                
            # find out if it is a http URL or a relative path
            if file_uri.lower().startswith('http'):
                # it is a http URL, retrieve the file
                import requests
                response = requests.get(file_uri)
                resource_object = response.json()
            else:
                file_uri = file_uri.replace('/', os.sep)
                path = os.path.join(os.path.dirname(base_uri), file_uri)
                # it is a file path, load the file
                with open(path) as file:
                    resource_object = json.load(file)
            if json_pointer:
                resource = resolve_pointer(resource_object, json_pointer)
            else:
                resource = resource_object
        except:
            print(f"Error loading model definition from {file_uri}")
            raise
    return resource

def resolve_imports(basedir, node):
    """ recursively resolve all $includes in the model definition """

    if isinstance(node, dict):
        if "$include" in node:
            obj_ref = ''
            file_ref = node["$include"]
            # strip # anchor portion from the file reference
            if "#" in file_ref:
                fr = file_ref.split("#")
                file_ref = fr[0]
                obj_ref = fr[1]
            file_ref = file_ref.replace('/', os.sep)
            import_file = os.path.join(basedir, file_ref)
            with open(import_file) as file:
                import_definition = json.load(file)
            del node["$include"]
            if obj_ref:
                node.update(resolve_pointer(import_definition, obj_ref))
            else:
                node.update(import_definition)
        for k,v in node.items():
            node[k] = resolve_imports(basedir, v)
    elif isinstance(node, list):
        for i, item in enumerate(node):
            node[i] = resolve_imports(basedir, item)
    return node

def main():
    parser = argparse.ArgumentParser(description='Generate JSON schema from model definition')
    parser.add_argument('--type', type=str, help='type of document to generate', choices=['json-schema', 'avro-schema', 'openapi', 'xregistry-model'], default='json-schema')
    parser.add_argument('--output', type=str, help='Path for output file', default='', required=False)
    parser.add_argument('--list', action='store_true', help='List all available models')
    parser.add_argument('--models', type=str, nargs='*', help='Specific models to include (default: all)', default=None)
    parser.add_argument('input_files', type=str, help='Path to input files (optional if using --models or --list)', nargs='*', default=[])

    args = parser.parse_args()

    if args.list:
        list_models()
        return

    json_schema = None
    model_definition = { "groups": {} }

    # If models are specified, use model discovery
    if args.models is not None:
        available_models = discover_models()
        if args.models == []:  # --models with no arguments means all models
            models_to_use = list(available_models.keys())
        else:
            models_to_use = args.models
        
        for model_name in models_to_use:
            if model_name not in available_models:
                print(f"Error: Model '{model_name}' not found. Available models: {list(available_models.keys())}")
                return
            
            input_file = available_models[model_name]
            with open(input_file) as file:
                print(f"> {model_name} ({input_file}) as '{args.type}'")
                input_definition = json.load(file)
                input_definition = resolve_imports(os.path.dirname(input_file), input_definition)
                if "groups" in input_definition:
                    for group_name, group_definition in input_definition["groups"].items():
                        file_name = file.name.replace('/', os.sep)
                        group_definition["$source"] = os.path.join(os.getcwd(), file_name)
                        if group_name not in model_definition["groups"]:
                            model_definition["groups"][group_name] = group_definition
    
    # Process input files if provided
    for input_file in args.input_files:
        with open(input_file) as file:
            print(f"> {input_file} as '{args.type}'")
            input_definition = json.load(file)
            input_definition = resolve_imports(os.path.dirname(input_file), input_definition)
            if "groups" in input_definition:
                for group_name, group_definition in input_definition["groups"].items():
                    file_name = file.name.replace('/', os.sep)
                    group_definition["$source"] = os.path.join(os.getcwd(), file_name)
                    if group_name not in model_definition["groups"]:
                        model_definition["groups"][group_name] = group_definition

    # If no models or files specified, use all models by default
    if not args.input_files and args.models is None:
        available_models = discover_models()
        for model_name, model_file in available_models.items():
            with open(model_file) as file:
                print(f"> {model_name} ({model_file}) as '{args.type}'")
                input_definition = json.load(file)
                input_definition = resolve_imports(os.path.dirname(model_file), input_definition)
                if "groups" in input_definition:
                    for group_name, group_definition in input_definition["groups"].items():
                        file_name = file.name.replace('/', os.sep)
                        group_definition["$source"] = os.path.join(os.getcwd(), file_name)
                        if group_name not in model_definition["groups"]:
                            model_definition["groups"][group_name] = group_definition

    if (args.type == 'json-schema'):
        json_schema = generate_json_schema(model_definition)
        if args.output:
            with open(args.output, 'w') as of:
                json.dump(json_schema, of, indent=2)
        else:
            print(json.dumps(json_schema, indent=2))
    elif (args.type == 'avro-schema'):
        avro_schema = generate_avro_schema(model_definition)
        if args.output:
            with open(args.output, 'w') as of:
                json.dump(avro_schema, of, indent=2)
        else:
            print(json.dumps(avro_schema, indent=2))
    elif (args.type == 'openapi'):
        openapi = generate_openapi(model_definition)
        if args.output:
            with open(args.output, 'w') as of:
                json.dump(openapi, of, indent=2)
        else:
            print(json.dumps(openapi, indent=2))
    elif (args.type == 'xregistry-model'):
        # For xregistry-model, output the combined model definition itself
        # Remove internal $source fields before output
        def clean_model(obj):
            if isinstance(obj, dict):
                cleaned = {}
                for k, v in obj.items():
                    if k != "$source":  # Skip $source fields
                        cleaned[k] = clean_model(v)
                return cleaned
            elif isinstance(obj, list):
                return [clean_model(item) for item in obj]
            else:
                return obj
        
        cleaned_model = clean_model(model_definition)
        
        if args.output:
            with open(args.output, 'w') as of:
                json.dump(cleaned_model, of, indent=2)
        else:
            print(json.dumps(cleaned_model, indent=2))

if __name__ == '__main__':
    main() 