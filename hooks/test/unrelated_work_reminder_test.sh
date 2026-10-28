#!/usr/bin/env bash
# Feeds SessionStart hook-input JSON to unrelated-work-reminder.sh and
# asserts that LAW 42 is injected once per session inside a git repo, and
# stays silent outside one and under the kill switches (issue #41).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../dev-rules/unrelated-work-reminder.sh"
fail=0
START='{"hook_event_name":"SessionStart","source":"startup"}'

run_in() { # dir, json [, extra env assignment]
  ( cd "$1" && CLAUDE_PROJECT_DIR="$1" ${3:+env "$3"} bash "$HOOK" <<<"$2" )
}
announces() {
  jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' <<<"$1" >/dev/null 2>&1 \
    && grep -q 'LAW 42' <<<"$1" && grep -q 'separate session' <<<"$1" \
    && grep -q -- '--state all' <<<"$1" && grep -q 'TYPE - #N title' <<<"$1"
}
mkrepo() { local d; d="$(mktemp -d)"; git -C "$d" init -q; echo "$d"; }

# 1. inside a git repo -> LAW 42 injected as SessionStart context (valid JSON).
d="$(mkrepo)"
out="$(run_in "$d" "$START")"
if announces "$out"; then echo "ok  : git repo -> LAW 42 announced"; else echo "FAIL: git repo should announce LAW 42"; fail=1; fi
# 1b. every SessionStart source (resume/clear/compact) re-injects it.
out="$(run_in "$d" '{"hook_event_name":"SessionStart","source":"compact"}')"
if announces "$out"; then echo "ok  : compact -> LAW 42 announced"; else echo "FAIL: compact should re-announce LAW 42"; fail=1; fi

# 2. kill switches silence it.
out="$(run_in "$d" "$START" DEV_RULES_OFF=1)"
if [ -z "$out" ]; then echo "ok  : DEV_RULES_OFF=1 -> silent"; else echo "FAIL: DEV_RULES_OFF=1 should silence"; fail=1; fi
mkdir -p "$d/.dev-rules"; : >"$d/.dev-rules/.off"
out="$(run_in "$d" "$START")"
if [ -z "$out" ]; then echo "ok  : .off -> silent"; else echo "FAIL: .off should silence"; fail=1; fi
rm -rf "$d/.dev-rules"
printf '{"enabled": false}' >"$d/.dev-rules.json"
out="$(run_in "$d" "$START")"
if [ -z "$out" ]; then echo "ok  : enabled:false -> silent"; else echo "FAIL: enabled:false should silence"; fail=1; fi
rm -rf "$d"

# 3. not a git repo -> silent, exit 0.
d="$(mktemp -d)"
out="$(run_in "$d" "$START")"; rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then echo "ok  : non-repo silent"; else echo "FAIL: non-repo must be silent exit 0"; fail=1; fi
rm -rf "$d"

# 4. malformed stdin inside a repo -> still exits 0 (stdin is not needed).
d="$(mkrepo)"
out="$(run_in "$d" 'not-json')"; rc=$?
if [ "$rc" = 0 ] && announces "$out"; then echo "ok  : malformed stdin exits 0 and announces"; else echo "FAIL: malformed stdin rc=$rc"; fail=1; fi
rm -rf "$d"

exit $fail
