#!/usr/bin/env bash
# Responsibility: report MCP servers declared more than once across the config sources.
set -uo pipefail

python3 <<'PY'
import glob, json, os

home = os.environ["HYGIENE_HOME"]
seen = {}

def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return None

def add(name, where):
    places = seen.setdefault(name, [])
    if where not in places:
        places.append(where)

config = load(os.path.join(os.path.dirname(home), ".claude.json")) or {}
for name in (config.get("mcpServers") or {}):
    add(name, "~/.claude.json")
for project, body in (config.get("projects") or {}).items():
    for name in ((body or {}).get("mcpServers") or {}):
        add(name, f"~/.claude.json projects[{os.path.basename(project)}]")

for path in glob.glob(os.path.join(home, "plugins", "cache", "*", "*", "*", ".mcp.json")):
    for name in ((load(path) or {}).get("mcpServers") or {}):
        add(name, f"plugin {path.split(os.sep)[-3]}")

for name, places in sorted(seen.items()):
    if len(places) > 1:
        print(f"  MCP server '{name}' declared {len(places)}x: {', '.join(places)}"
              " - each copy loads its whole tool list into every session")
PY
