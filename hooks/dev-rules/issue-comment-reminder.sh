#!/usr/bin/env bash
# PostToolUse(Bash): after a git push on an issue branch
# (feature/issue-N, bugfix/issue-N, ...), remind to comment the issue with
# the commit hash(es), files changed, and build/test result.
# Reminder ONLY -- never blocks; silent off issue branches (issue #5).
set -euo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
printf '%s' "$cmd" | grep -qE '(^|[[:space:]&|])git[[:space:]]+push' || exit 0

# Honor the dev-rules kill switches (DEV_RULES_OFF=1 / .dev-rules/.off /
# .dev-rules.json enabled:false) -- one off switch silences everything.
. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

proj="${CLAUDE_PROJECT_DIR:-.}"
branch="$(git -C "$proj" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
issue="$(printf '%s' "$branch" | grep -oE 'issue-[0-9]+' | grep -oE '[0-9]+' | head -1 || true)"
[ -z "$issue" ] && exit 0

jq -n --arg i "$issue" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("Pushed on issue branch -- comment issue #"+$i+" now: run `gh issue comment "+$i+"` with the commit hash(es), files changed, and build/test result.")}}'
