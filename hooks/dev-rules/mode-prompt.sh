#!/usr/bin/env bash
# UserPromptSubmit (dev-rules): announce LAW 13 at the START of a flow.
# When no mode has been chosen for this cycle (no .mode-feature and no
# .red-first-unlocked), inject the bug-vs-feature instruction so the gate
# engages before the first production read, not at it (issue #6).
# The mode is per workspace (issue #26): the session cwd's .solvers/<name>/,
# else the project root. A root session never gets told to put sentinels in
# the root while .solvers/ workspaces exist.
# Context only -- this hook never blocks anything.
set -euo pipefail

input="$(cat || true)"
command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

proj="${CLAUDE_PROJECT_DIR:-.}"; proj="${proj%/}"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
ws="$(dr_workspace "${cwd:-$proj}")"
dr_sentinel "$ws" .mode-feature && exit 0
dr_sentinel "$ws" .red-first-unlocked && exit 0

if [ "$ws" != "$proj" ]; then
  at="${ws#"$proj"/}/.dev-rules"
elif ls -d "$proj"/.solvers/*/ >/dev/null 2>&1; then
  at=".solvers/<name>/.dev-rules"   # workspaces in use: never the root
else
  at=".dev-rules"
fi

jq -n --arg at "$at" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:("dev-rules LAW 13 -- no mode is set for this cycle. Before reading or editing production code, ask the user which flow applies: (a) BUG: write the failing test from the INTENDED behavior FIRST (reading the buggy code first contaminates the oracle), see it RED, then touch \($at)/.red-first-unlocked; (b) FEATURE/IMPROVEMENT: brainstorm, then touch \($at)/.mode-feature; (c) the dev may DISABLE the gates: touch .dev-rules/.off or relaunch with DEV_RULES_OFF=1. Sentinels are per workspace: create them in the workspace you will work in (the .solvers/<name>/ clone, or the root when no clone is used). Pure Q&A/docs work needs no mode.")}}'
