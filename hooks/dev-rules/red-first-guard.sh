#!/usr/bin/env bash
# dev-rules RED-first + mode-aware read gate (language-agnostic).
# Plugin hook: it runs from the plugin cache, so the PROJECT root comes from
# $CLAUDE_PROJECT_DIR, never BASH_SOURCE.
#
# Sentinels live in <workspace>/.dev-rules/, where the workspace is the one
# the call TARGETS (issue #26): the nearest .solvers/<name>/ ancestor of the
# path, else the project root. A sentinel never unlocks another workspace.
#   none               -> bug discipline: production READ and EDIT blocked.
#   .mode-feature      -> feature flow: READ and EDIT allowed (red-first is the
#                         BUG gate; features are governed by the plan, not RED).
#   .red-first-unlocked-> production READ and EDIT allowed.
# Test files, docs, config: never blocked.
set -euo pipefail

input="$(cat)"

# Degrade gracefully if jq is missing: cannot inspect the call -> allow + warn.
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"dev-rules gate skipped: jq not found on PATH (install jq to enable RED-first enforcement)."}}'
  exit 0
fi

# Malformed / empty stdin: nothing to inspect -> allow cleanly (never crash on a
# jq parse error). Claude Code always sends valid JSON; this is belt-and-braces.
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // "."')}"
proj="${proj%/}"
base="$(printf '%s' "$input" | jq -r '.cwd // empty')"; base="${base:-$proj}"

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0


# Classify intent (read vs write) and gather the target path(s). A tool's
# file_path / path / glob is ONE path each, never word-split, so a path with a
# space keeps its workspace (#30); a Bash command splits into shell words,
# quotes honored, so a quoted path with a space is one word too (#31).
# A leading ~ is $HOME, as the shell expands it (#29).
intent="read"; toks=()
fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[ -z "$fp" ] || fp="$(dr_expand_tilde "$fp")"
case "$tool" in
  Read)  [ -z "$fp" ] || toks=("$fp") ;;
  Grep|Glob)
    for k in path glob; do
      v="$(printf '%s' "$input" | jq -r --arg k "$k" '.tool_input[$k] // empty')"
      [ -z "$v" ] || toks+=("$(dr_expand_tilde "$v")")
    done ;;
  Edit|Write) intent="write"; [ -z "$fp" ] || toks=("$fp") ;;
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    c=" $cmd "   # pad so a leading/trailing command token still matches the spaced arms;
                 # ">"[!&] catches file redirects (> >> >file) but NOT 2>&1 / &> -- so a
                 # read that merely redirects stderr is not misclassified as a write.
    case "$c" in
      *">"[!\&]*|*" sed -i"*|*" tee "*|*" dd "*) intent="write" ;;
      *" grep "*|*" rg "*|*" cat "*|*" sed "*|*" awk "*|*" head "*|*" tail "*|*" less "*|*" nl "*|*" ls "*|*" find "*|*" tree "*) intent="read" ;;
      *) exit 0 ;;
    esac
    # Shell words (redirects split off, tilde expanded). A word with `:` names
    # several paths (docker -v "$PWD:/src", PATH-like lists): each part on its own.
    dr_shell_words "$cmd"
    base="$(dr_words_cwd "$base")"   # cd <dir> && ... / git -C <dir>
    for word in ${DR_WORDS[@]+"${DR_WORDS[@]}"}; do
      while :; do
        [ -z "${word%%:*}" ] || toks+=("${word%%:*}")
        case "$word" in *:*) word="${word#*:}" ;; *) break ;; esac
      done
    done ;;
  *) exit 0 ;;
esac
[ "${#toks[@]}" -gt 0 ] || exit 0

# Production implicated (and not a test file)? Each token resolves against the
# effective cwd; its workspace (.solvers/<name>/ or the root) owns the sentinel,
# and production_globs match the path relative to that workspace. A path in no
# workspace (outside the project and every .solvers/<name>/, e.g. /src inside a
# container) is not this project's file: skipped, never root production (#28).
prod_touched=""; ws=""
for tok in "${toks[@]}"; do
  case "$tok" in /*) abs="$tok" ;; *) abs="${base%/}/$tok" ;; esac
  w="$(dr_workspace "$abs")"
  case "$abs" in "$w"/*) rel="${abs#"$w"/}" ;; *) continue ;; esac
  if dr_is_production "$rel" "$w"; then prod_touched="yes"; ws="$w"; break; fi
done
[ -n "$prod_touched" ] || exit 0

case "$ws" in "$proj") at=".dev-rules" ;; *) at="${ws#"$proj"/}/.dev-rules" ;; esac
red_unlocked() { dr_sentinel "$ws" ".red-first-unlocked"; }
feature_mode() { dr_sentinel "$ws" ".mode-feature"; }

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

if [ "$intent" = "write" ]; then
  red_unlocked && exit 0
  feature_mode && exit 0
  deny "Production EDIT locked (dev-rules). Do NOT pick a flow yourself -- ASK THE USER which applies: (a) BUG: write the failing test for the INTENDED behavior, run it, SEE it fail (RED), then create $at/.red-first-unlocked; (b) FEATURE/IMPROVEMENT: create $at/.mode-feature after brainstorming (plan-governed, not RED); (c) the dev may DISABLE the gates: touch .dev-rules/.off (until removed) or relaunch with DEV_RULES_OFF=1."
else
  red_unlocked && exit 0
  feature_mode && exit 0
  deny "Read-locked (dev-rules LAW 13). Do NOT pick a flow yourself -- ASK THE USER which applies: (a) BUG: write the failing test from the INTENDED behavior BEFORE reading the code (reading the buggy code first contaminates the oracle), see it RED, then create $at/.red-first-unlocked; (b) FEATURE/IMPROVEMENT: after brainstorming, create $at/.mode-feature (plan-governed; unlocks read and edit); (c) the dev may DISABLE the gates: touch .dev-rules/.off (until removed) or relaunch with DEV_RULES_OFF=1."
fi
