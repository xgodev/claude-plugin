#!/usr/bin/env bash
# PostToolUse(Bash): after a `git commit` that the same command does not
# push, remind to fetch and push right away -- a commit that stays local is
# invisible to every other clone, CI and dependent repo.
# Reminder ONLY -- never blocks.
set -euo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
git_re='(^|[[:space:]&|;(])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'
printf '%s' "$cmd" | grep -qE "${git_re}commit([[:space:]]|$)" || exit 0
printf '%s' "$cmd" | grep -qE "${git_re}push([[:space:]]|$)" && exit 0

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Committed but not pushed -- push it now: `git fetch` then `git push` (if the remote moved: `git pull --rebase`, retest, push). Never leave a commit local."}}'
