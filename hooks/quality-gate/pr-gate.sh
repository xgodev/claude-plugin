#!/usr/bin/env bash
# pr-gate.sh -- PreToolUse hook (quality-gate plugin).
# Blocks `gh pr create` unless the gate passes for HEAD. The gate belongs to
# the PR moment (and CI) -- `git push` is NEVER gated: pushing work-in-progress
# must stay cheap, and on a heavy project a per-push gate costs minutes.
# English only. Fails OPEN on its own errors: a broken hook must never
# brick the user's git.

set -uo pipefail

input="$(cat)"

# jq is required to parse the tool input; without it, fail open.
if ! command -v jq >/dev/null 2>&1; then
  echo "qg-hook: jq not found; skipping gate enforcement" >&2
  exit 0
fi

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0   # not a readable Bash command -> allow

# --- decide whether a gated operation is present ---------------------------
# Match `gh pr create` as the leading tokens of any &&/||/;/| segment (not a
# bare substring), after stripping leading env assignments (FOO=bar cmd).
should_gate=0
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//')"
  case "$seg" in
    "gh pr create"|"gh pr create "*) should_gate=1 ;;
  esac
done <<< "$(printf '%s' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')"

[ "$should_gate" -eq 1 ] || exit 0

# --- locate project + plugin ----------------------------------------------
proj="${CLAUDE_PROJECT_DIR:-$PWD}"
plugin="${CLAUDE_PLUGIN_ROOT:-}"
qg_bin="$plugin/tools/quality-gate/qg"
if [ -z "$plugin" ] || [ ! -x "$qg_bin" ]; then
  echo "qg-hook: qg not found at CLAUDE_PLUGIN_ROOT; skipping enforcement" >&2
  exit 0
fi
git -C "$proj" rev-parse --show-toplevel >/dev/null 2>&1 || exit 0   # not a repo -> allow

# --- resolve base ref (upstream -> origin default -> absolute) ------------
base="$(git -C "$proj" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [ -z "$base" ]; then
  base="$(git -C "$proj" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
fi

# --- run the gate ----------------------------------------------------------
if [ -n "$base" ]; then
  out="$(cd "$proj" && "$qg_bin" --base "$base" 2>&1)"; rc=$?
else
  out="$(cd "$proj" && "$qg_bin" 2>&1)"; rc=$?   # absolute mode
fi

# --- map exit code to decision --------------------------------------------
case "$rc" in
  0|3) exit 0 ;;   # passed / bypassed / no-language -> allow
esac

verdict="regressed/failed"
[ "$rc" -eq 2 ] && verdict="tool error"
tail_out="$(printf '%s' "$out" | tail -n 6 | tr '\n' ' ')"
reason="Quality gate ${verdict} (qg exit ${rc}). ${tail_out} -- run the gate and fix, or set QG_BYPASS_REASON to override."

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
