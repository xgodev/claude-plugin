#!/usr/bin/env bash
# Responsibility: report subagent dispatch left enabled where nobody is using it.
set -uo pipefail

# Fanning out into subagents is legitimate work when it is asked for -- each
# one just bills separately, and the cost is invisible. So the defect is not
# "enabled", it is "enabled and idle": a project that carries the dispatch
# skills in every session and has not dispatched anything in weeks.
export HYGIENE_IDLE_DAYS="${HYGIENE_IDLE_DAYS:-30}"

python3 <<'PY'
import json, os, re, time

home = os.environ["HYGIENE_HOME"]
idle_days = int(os.environ["HYGIENE_IDLE_DAYS"])
cutoff = time.time() - idle_days * 86400
dispatch_tools = {"Task", "Agent", "Workflow", "TaskOutput", "SendMessage"}

def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return None

def enabled(project_dir):
    """True when any settings file under the project turns superpowers on."""
    for name in ("settings.json", "settings.local.json"):
        data = load(os.path.join(project_dir, ".claude", name))
        if not isinstance(data, dict):
            continue
        for plugin, on in (data.get("enabledPlugins") or {}).items():
            if on and "superpowers" in plugin:
                return plugin
    return None

def last_dispatch(project_dir):
    """When this project last actually spawned an agent, or None."""
    slug = re.sub(r"[^A-Za-z0-9]", "-", project_dir)
    sessions = os.path.join(home, "projects", slug)
    if not os.path.isdir(sessions):
        return None
    newest = None
    for entry in os.scandir(sessions):
        if not entry.name.endswith(".jsonl"):
            continue
        # A transcript older than the window cannot carry a recent dispatch,
        # and these files are large enough that skipping them matters.
        if entry.stat().st_mtime < cutoff:
            continue
        try:
            with open(entry.path) as fh:
                for line in fh:
                    if not any(f'"name":"{t}"' in line for t in dispatch_tools):
                        continue
                    stamp = json.loads(line).get("timestamp")
                    if stamp and (newest is None or stamp > newest):
                        newest = stamp
        except Exception:
            continue
    return newest

for root in os.environ["HYGIENE_ROOTS"].split(":"):
    for dirpath, dirnames, _ in os.walk(root):
        if dirpath[len(root):].count(os.sep) > 4:
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames
                       if d not in (".git", "node_modules", "target", ".solvers", "dist", "build")]
        if ".claude" not in dirnames:
            continue
        plugin = enabled(dirpath)
        if not plugin:
            continue
        used = last_dispatch(dirpath)
        if used:
            continue
        print(f"  {os.path.relpath(dirpath, root)}: {plugin} is ON but nothing was"
              f" dispatched in {idle_days} days - it costs context every session")
PY
