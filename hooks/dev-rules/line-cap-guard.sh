#!/usr/bin/env bash
# dev-rules line-cap guard (language-agnostic, on by default).
# Denies Edit/Write that GROW a source file already over its line cap,
# forcing a split BEFORE the file gets bigger. Shrinking edits/writes
# (the split itself) always pass, as do new files, test files, and
# docs/config.
# Per-repo tuning in .dev-rules.json:
#   "line_cap_guard": false            -> disable entirely
#   "line_cap_default": 800            -> global default cap (default 500)
#   "line_caps": {".go": 600, ...}     -> per-extension caps
set -euo pipefail

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"dev-rules line-cap guard skipped: jq not found on PATH."}}'
  exit 0
fi
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
case "$tool" in Edit|Write) ;; *) exit 0 ;; esac

proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // "."')}"

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0
[ "$(dr_config '.line_cap_guard' 'true')" != "false" ] || exit 0

target="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[ -n "$target" ] || exit 0
[ -f "$target" ] || exit 0   # new files always pass

rel="${target#"$proj"/}"
case "$rel" in .solvers/*/*) rel="${rel#.solvers/*/}" ;; esac
dr_is_test_file "$rel" && exit 0
dr_is_docs_or_config "$rel" && exit 0

ext=".${target##*.}"
case "$target" in */*.*) ;; *) exit 0 ;; esac   # no extension -> skip
cap="$(dr_config ".line_caps[\"$ext\"]" '')"
[ -n "$cap" ] || cap="$(dr_config '.line_cap_default' '500')"
case "$cap" in ''|*[!0-9]*) exit 0 ;; esac

lines="$(wc -l < "$target" | tr -d ' ')"
[ "$lines" -gt "$cap" ] || exit 0

# Over the cap: allow only operations that do not grow the file.
if [ "$tool" = "Edit" ]; then
  growth="$(printf '%s' "$input" | jq -r '
    def nl(s): (s // "" | [scan("\n")] | length);
    nl(.tool_input.new_string) - nl(.tool_input.old_string)')"
  [ "${growth:-0}" -gt 0 ] || exit 0
else
  new_lines="$(printf '%s' "$input" | jq -r '.tool_input.content // "" | [scan("\n")] | length')"
  [ "${new_lines:-0}" -gt "$lines" ] || exit 0
fi

jq -nc --arg r "File over its line cap (dev-rules line-cap guard): $rel has $lines lines, cap for $ext is $cap. Split it into focused modules BEFORE adding more lines -- shrinking edits and split rewrites pass. Tune per-repo in .dev-rules.json (line_caps / line_cap_default / line_cap_guard:false)." \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
