#!/usr/bin/env bash
# dev-rules main-folder guard (OPT-IN, language-agnostic).
# Enforces the isolated-workspace flow: when a project sets
#   {"main_folder_guard": true} in .dev-rules.json
# work must happen inside .solvers/<name>/ clones -- Edit/Write targeting
# the MAIN working tree is denied, and so are bare mutating VCS commands
# whose working tree is the main folder. Keyed off what the operation
# TARGETS, never the session root. Reads/greps are never blocked.
# Exempt: .solvers/**, .dev-rules/**, .claude/**, and paths outside the
# project root.
set -euo pipefail

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"dev-rules main-folder guard skipped: jq not found on PATH."}}'
  exit 0
fi
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // "."')}"

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0
# OPT-IN: only projects that explicitly enable it are gated.
[ "$(dr_config '.main_folder_guard' 'false')" = "true" ] || exit 0

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Edit|Write)
    target="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
    [ -n "$target" ] || exit 0
    # Outside the project root: not ours to gate.
    case "$target" in
      "$proj"/*) rel="${target#"$proj"/}" ;;
      /*) exit 0 ;;
      *) rel="$target" ;;
    esac
    case "$rel" in
      .solvers/*|.dev-rules/*|.claude/*) exit 0 ;;
    esac
    deny "An agent changing the MAIN working tree is not recommended (dev-rules main-folder guard). Do NOT decide alone -- ASK THE USER how to proceed: (a) RECOMMENDED: create the isolated clone yourself and edit there -- git worktree add .solvers/<name> -b <name>; name it issue-<n> when the work has a related issue, or a session/task slug when there is no related issue (e.g. sess-<yyyymmdd>-<short-task>); (b) the dev may disable this guard (\"main_folder_guard\": false in .dev-rules.json) or all dev-rules gates (touch .dev-rules/.off, or DEV_RULES_OFF=1)."
    ;;
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    [ -n "$cmd" ] || exit 0
    # Anything explicitly aimed at a .solvers clone is the sanctioned flow.
    case "$cmd" in *".solvers/"*) exit 0 ;; esac
    # Deny only bare MUTATING vcs subcommands (worktree/clone/status/log/diff/
    # fetch stay allowed -- they set up or inspect, they do not mutate the tree).
    c=" $cmd "
    for sub in commit push merge rebase "reset" "checkout" switch restore cherry-pick revert apply stash am; do
      case "$c" in
        *" git $sub "*|*" git $sub"|*" git -"*" $sub "*)
          deny "An agent mutating VCS in the MAIN working tree is not recommended (dev-rules main-folder guard). Do NOT decide alone -- ASK THE USER how to proceed: (a) RECOMMENDED: run git $sub inside a .solvers/<name>/ clone (git -C .solvers/<name> $sub ...); create it first if needed (git worktree add .solvers/<name> -b <name>; name it issue-<n> with a related issue, or a session/task slug like sess-<yyyymmdd>-<short-task> when there is no related issue); (b) the dev may disable this guard (\"main_folder_guard\": false in .dev-rules.json) or all dev-rules gates (touch .dev-rules/.off, or DEV_RULES_OFF=1)." ;;
      esac
    done
    exit 0
    ;;
  *) exit 0 ;;
esac
