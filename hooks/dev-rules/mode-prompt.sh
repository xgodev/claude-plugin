#!/usr/bin/env bash
# UserPromptSubmit (dev-rules): announce LAW 13 at the START of a flow.
# When no mode has been chosen for this cycle (no .mode-feature and no
# .red-first-unlocked), inject the bug-vs-feature instruction so the gate
# engages before the first production read, not at it (issue #6).
# Context only -- this hook never blocks anything.
set -euo pipefail

cat >/dev/null || true   # consume stdin; the prompt text is not needed
command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

proj="${CLAUDE_PROJECT_DIR:-.}"
[ -f "$proj/.dev-rules/.mode-feature" ] && exit 0
[ -f "$proj/.dev-rules/.red-first-unlocked" ] && exit 0

jq -n '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:"dev-rules LAW 13 -- no mode is set for this cycle. Before reading or editing production code, ask the user which flow applies: (a) BUG: write the failing test from the INTENDED behavior FIRST (reading the buggy code first contaminates the oracle), see it RED, then touch .dev-rules/.red-first-unlocked; (b) FEATURE/IMPROVEMENT: brainstorm, then touch .dev-rules/.mode-feature; (c) the dev may DISABLE the gates: touch .dev-rules/.off or relaunch with DEV_RULES_OFF=1. Pure Q&A/docs work needs no mode."}}'
