import os
import json
from pathlib import Path
import pandas as pd
import subprocess

# Base directory to search
script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
root_dir = script_dir.parent
registry_dir = Path(os.path.join(root_dir, "registry"))

# Output index containers
server_index = []
tool_index = []
prompt_index = []
resource_index = []
agentcards_index = []

# Process MCP providers
mcp_base_dir = registry_dir / "mcpproviders"
if mcp_base_dir.exists():
    for provider_dir in mcp_base_dir.iterdir():
        if provider_dir.is_dir():
            if not (provider_dir / "servers").is_dir():
                continue
            for server_dir in (provider_dir / "servers").iterdir():
                index_file = server_dir / "index.json"
                if index_file.exists():
                    with open(index_file, 'r', encoding='utf-8') as f:
                        try:
                            server_data = json.load(f)
                        except json.JSONDecodeError:
                            continue

                        provider_id = provider_dir.name
                        server_id = server_dir.name

                        # Index server
                        server_index.append({
                            "id": f"{provider_id}/{server_id}",
                            "provider": provider_id,
                            "server": server_id,
                            "name": server_data.get("name"),
                            "description": server_data.get("description"),
                            "repo": server_data.get("repository", {}).get("url"),
                            "mcpversion": server_data.get("mcpversion"),
                            "serverversion": server_data.get("serverversion"),
                        })

                        # Index tools
                        for tool in server_data.get("tools", []):
                            tool_index.append({
                                "id": f"{provider_id}/{server_id}/{tool.get('name')}",
                                "provider": provider_id,
                                "server": server_id,
                                "type": "tool",
                                "name": tool.get("name"),
                                "description": tool.get("description"),
                            })

                        # Index prompts
                        for prompt in server_data.get("prompts", []):
                            prompt_index.append({
                                "id": f"{provider_id}/{server_id}/{prompt.get('name')}",
                                "provider": provider_id,
                                "server": server_id,
                                "type": "prompt",
                                "name": prompt.get("name"),
                                "description": prompt.get("description"),
                            })

                        # Index resources
                        for resource in server_data.get("resources", []):
                            resource_index.append({
                                "id": f"{provider_id}/{server_id}/{resource.get('name')}",
                                "provider": provider_id,
                                "server": server_id,
                                "type": "resource",
                                "name": resource.get("name"),
                                "description": resource.get("description"),
                                "uritemplate": resource.get("uritemplate"),
                                "mimetype": resource.get("mimetype"),
                            })

# Process Agent Card providers
agentcard_base_dir = registry_dir / "agentcardproviders"
if agentcard_base_dir.exists():
    for provider_dir in agentcard_base_dir.iterdir():
        if provider_dir.is_dir():
            if not (provider_dir / "agentcards").is_dir():
                continue
            for agentcard_dir in (provider_dir / "agentcards").iterdir():
                index_file = agentcard_dir / "index.json"
                if index_file.exists():
                    with open(index_file, 'r', encoding='utf-8') as f:
                        try:
                            agentcard_data = json.load(f)
                        except json.JSONDecodeError:
                            continue

                        provider_id = provider_dir.name
                        agentcard_id = agentcard_dir.name

                        # Index agent card
                        agentcards_index.append({
                            "id": f"{provider_id}/{agentcard_id}",
                            "provider": provider_id,
                            "agentcard": agentcard_id,
                            "name": agentcard_data.get("name"),
                            "description": agentcard_data.get("description"),
                            "version": agentcard_data.get("version"),
                            "manifestUrl": agentcard_data.get("manifestUrl"),
                        })

# Write index files to the current directory as JSON array files
output_dir = script_dir

with open(output_dir / "server_index.json", "w", encoding="utf-8") as f:
    json.dump(server_index, f, ensure_ascii=False, indent=4)

with open(output_dir / "tool_index.json", "w", encoding="utf-8") as f:
    json.dump(tool_index, f, ensure_ascii=False, indent=4)

with open(output_dir / "prompt_index.json", "w", encoding="utf-8") as f:
    json.dump(prompt_index, f, ensure_ascii=False, indent=4)

with open(output_dir / "resource_index.json", "w", encoding="utf-8") as f:
    json.dump(resource_index, f, ensure_ascii=False, indent=4)

with open(output_dir / "agentcards_index.json", "w", encoding="utf-8") as f:
    json.dump(agentcards_index, f, ensure_ascii=False, indent=4)

print(f"Generated indices:")
print(f"  - {len(server_index)} MCP servers")
print(f"  - {len(tool_index)} tools")
print(f"  - {len(prompt_index)} prompts") 
print(f"  - {len(resource_index)} resources")
print(f"  - {len(agentcards_index)} agent cards")
    
# Define the directory containing the package.json for flex-indexer
flex_indexer_dir = Path(script_dir) / "flex-indexer"

if flex_indexer_dir.exists() and (flex_indexer_dir / "package.json").exists():
    try:
        # Run npm install to install dependencies
        if os.name == 'nt':  # Windows
            subprocess.run(["npm.cmd", "install"], cwd=flex_indexer_dir, check=True, shell=True)
            subprocess.run(["npm.cmd", "start"], cwd=flex_indexer_dir, check=True, shell=True)
        else:  # Unix-like systems
            subprocess.run(["npm", "install"], cwd=flex_indexer_dir, check=True)
            subprocess.run(["npm", "start"], cwd=flex_indexer_dir, check=True)
        print("Flex indexer completed successfully")
    except subprocess.CalledProcessError as e:
        print(f"Warning: Flex indexer failed: {e}")
else:
    print("Warning: Flex indexer directory not found, skipping flex index generation")
