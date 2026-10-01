#!/usr/bin/env bash
# Responsibility: report settings that let a session fan out into subagents.
set -uo pipefail

# Each of these makes the agent spawn sessions that bill separately, and the
# cost is invisible to the person who never asked for the fan-out.
export HYGIENE_DISPATCHERS="${HYGIENE_DISPATCHERS:-dispatching-parallel-agents subagent-driven-development using-superpowers workflow-authoring}"

python3 <<'PY'
import json, os

home = os.environ["HYGIENE_HOME"]
dispatchers = os.environ["HYGIENE_DISPATCHERS"].split()

def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return None

def plugins_on(path, label):
    data = load(path)
    if not isinstance(data, dict):
        return
    for name, on in (data.get("enabledPlugins") or {}).items():
        if on and "superpowers" in name:
            print(f"  {label}: plugin {name} is ON - it ships the subagent-dispatch skills")

plugins_on(os.path.join(home, "settings.json"), "user settings")

for root in os.environ["HYGIENE_ROOTS"].split(":"):
    for dirpath, dirnames, _ in os.walk(root):
        if dirpath[len(root):].count(os.sep) > 4:
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames
                       if d not in (".git", "node_modules", "target", ".solvers", "dist", "build")]
        if ".claude" not in dirnames:
            continue
        for name in ("settings.json", "settings.local.json"):
            path = os.path.join(dirpath, ".claude", name)
            if os.path.exists(path):
                plugins_on(path, os.path.relpath(dirpath, root))

# Turning the skills off at the user level covers every project, so the gap is
# only worth reporting there.
overrides = (load(os.path.join(home, "settings.json")) or {}).get("skillOverrides") or {}
gaps = [s for s in dispatchers
        if overrides.get(s) != "off" and overrides.get(f"superpowers:{s}") != "off"]
if gaps:
    print(f"  user settings: no skillOverrides=off for {', '.join(gaps)}")
PY
