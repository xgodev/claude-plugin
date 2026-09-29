#!/usr/bin/env bash
# Feeds hook-input JSON to mode-prompt.sh (UserPromptSubmit) and asserts
# that LAW 13 is announced at the START of a flow when no mode is chosen,
# and stays silent otherwise (issue #6).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../dev-rules/mode-prompt.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0
PROMPT='{"hook_event_name":"UserPromptSubmit","prompt":"fix the crash in the parser"}'

run_hook() { printf '%s' "$PROMPT" | bash "$HOOK"; }
announces() {
  grep -q '"additionalContext"' <<<"$1" && grep -qi 'bug' <<<"$1" \
    && grep -qi 'feature' <<<"$1" && grep -qi 'failing test' <<<"$1"
}
reset() { rm -rf "$SBX/.dev-rules"; }

# 1. No mode chosen => the hook injects the LAW 13 instruction (ask bug vs
# feature; bug => failing test before reading production).
reset
out="$(run_hook)"
if announces "$out"; then echo "ok  : no mode -> LAW 13 announced"; else echo "FAIL: no mode should announce LAW 13 (bug vs feature + failing test)"; fail=1; fi

# 2. Mode already chosen => silent.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.mode-feature"
out="$(run_hook)"
if [ -z "$out" ]; then echo "ok  : .mode-feature -> silent"; else echo "FAIL: .mode-feature should silence the announcement"; fail=1; fi
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.red-first-unlocked"
out="$(run_hook)"
if [ -z "$out" ]; then echo "ok  : .red-first-unlocked -> silent"; else echo "FAIL: .red-first-unlocked should silence the announcement"; fail=1; fi

# 3. Kill switches silence it.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.off"
out="$(run_hook)"
if [ -z "$out" ]; then echo "ok  : .off -> silent"; else echo "FAIL: .off should silence the announcement"; fail=1; fi
reset
out="$(printf '%s' "$PROMPT" | DEV_RULES_OFF=1 bash "$HOOK")"
if [ -z "$out" ]; then echo "ok  : DEV_RULES_OFF=1 -> silent"; else echo "FAIL: DEV_RULES_OFF=1 should silence the announcement"; fail=1; fi
reset
printf '%s' '{"enabled":false}' > "$SBX/.dev-rules.json"
out="$(run_hook)"
if [ -z "$out" ]; then echo "ok  : enabled:false -> silent"; else echo "FAIL: enabled:false should silence the announcement"; fail=1; fi
rm -f "$SBX/.dev-rules.json"

# 5. Issue #26: the sentinel checked is the SESSION cwd's workspace.
reset; rm -rf "$SBX/.solvers"
mkdir -p "$SBX/.solvers/A/.dev-rules" "$SBX/.solvers/B"; : >"$SBX/.solvers/A/.dev-rules/.mode-feature"
pj() { printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"x"}' "$1"; }
out="$(pj "$SBX/.solvers/A" | bash "$HOOK")"
if [ -z "$out" ]; then echo "ok  : cwd A with sentinel -> silent"; else echo "FAIL: cwd A with sentinel should be silent"; fail=1; fi
out="$(pj "$SBX/.solvers/B" | bash "$HOOK")"
if announces "$out" && grep -q '.solvers/B/.dev-rules/' <<<"$out"; then echo "ok  : cwd B -> announced for B"; else echo "FAIL: cwd B must announce and point at .solvers/B/.dev-rules/"; fail=1; fi
# Root sentinel does not silence a workspace session.
mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.mode-feature"
out="$(pj "$SBX/.solvers/B" | bash "$HOOK")"
if announces "$out"; then echo "ok  : root sentinel does not silence B"; else echo "FAIL: root sentinel must not silence B"; fail=1; fi
rm -rf "$SBX/.dev-rules"
# Root session while workspaces exist: never tell the agent to touch root sentinels.
out="$(pj "$SBX" | bash "$HOOK")"
if announces "$out" && ! grep -Eq 'touch \.dev-rules/\.(mode-feature|red-first-unlocked)' <<<"$out" && grep -q '.solvers/<name>/.dev-rules/' <<<"$out"; then
  echo "ok  : root session with workspaces -> points at .solvers/<name>/"
else
  echo "FAIL: root session with workspaces must not suggest root sentinels"; fail=1
fi
rm -rf "$SBX/.solvers"

# 4. Malformed stdin must not crash or block.
printf '%s' 'not-json' | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "ok  : malformed stdin exits 0"; else echo "FAIL: malformed stdin exit $rc"; fail=1; fi

exit $fail
