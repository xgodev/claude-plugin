#!/usr/bin/env bash
# Feeds hook-input JSON to line-cap-guard.sh and asserts deny/allow.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/../dev-rules/line-cap-guard.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }
run() { printf '%s' "$2" | bash "$GUARD"; }
mkfile() { # path lines
  mkdir -p "$(dirname "$1")"; seq 1 "$2" | sed 's/^/line /' > "$1"
}

printf '%s' '{"line_caps": {".go": 100}}' > "$SBX/.dev-rules.json"

# 1. New file (does not exist): allowed.
out="$(run Write "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SBX/src/new.go\",\"content\":\"x\"}}")"
if denied "$out"; then echo "FAIL: new file must be allowed"; fail=1; else echo "ok  : new file allowed"; fi

# 2. File under cap: growing edit allowed.
mkfile "$SBX/src/small.go" 50
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/small.go\",\"old_string\":\"line 1\",\"new_string\":\"line 1\\nplus\"}}")"
if denied "$out"; then echo "FAIL: under-cap growth must be allowed"; fail=1; else echo "ok  : under-cap growth allowed"; fi

# 3. File OVER cap: growing edit DENIED.
mkfile "$SBX/src/big.go" 150
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/big.go\",\"old_string\":\"line 1\",\"new_string\":\"line 1\\nplus\"}}")"
if denied "$out"; then echo "ok  : over-cap growth denied"; else echo "FAIL: over-cap growth should be denied"; fail=1; fi

# 4. File over cap: SHRINKING edit allowed (that is the split happening).
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/big.go\",\"old_string\":\"line 1\\nline 2\\nline 3\",\"new_string\":\"line 1\"}}")"
if denied "$out"; then echo "FAIL: shrinking edit must be allowed"; fail=1; else echo "ok  : shrinking edit allowed"; fi

# 5. Write that reduces an over-cap file: allowed.
out="$(run Write "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SBX/src/big.go\",\"content\":\"short\\nfile\"}}")"
if denied "$out"; then echo "FAIL: shrinking write must be allowed"; fail=1; else echo "ok  : shrinking write allowed"; fi

# 6. Test files exempt even over cap.
mkfile "$SBX/src/big_test.go" 150
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/big_test.go\",\"old_string\":\"line 1\",\"new_string\":\"line 1\\nplus\"}}")"
if denied "$out"; then echo "FAIL: test file must be exempt"; fail=1; else echo "ok  : test file exempt"; fi

# 7. Docs exempt.
mkfile "$SBX/NOTES.md" 900
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/NOTES.md\",\"old_string\":\"line 1\",\"new_string\":\"line 1\\nplus\"}}")"
if denied "$out"; then echo "FAIL: docs must be exempt"; fail=1; else echo "ok  : docs exempt"; fi

# 8. Default cap (500) applies to extensions without explicit config.
mkfile "$SBX/src/huge.py" 600
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/huge.py\",\"old_string\":\"line 1\",\"new_string\":\"line 1\\nplus\"}}")"
if denied "$out"; then echo "ok  : default cap enforced"; else echo "FAIL: default cap should deny 600-line .py growth"; fail=1; fi

# 9. Opt-out: line_cap_guard=false disables everything.
printf '%s' '{"line_cap_guard": false}' > "$SBX/.dev-rules.json"
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/huge.py\",\"old_string\":\"line 1\",\"new_string\":\"line 1\\nplus\"}}")"
if denied "$out"; then echo "FAIL: opt-out must disable the guard"; fail=1; else echo "ok  : opt-out disables guard"; fi
printf '%s' '{}' > "$SBX/.dev-rules.json"

# 10. Malformed stdin: clean allow.
printf '%s' 'not-json' | bash "$GUARD" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "ok  : malformed stdin exits 0"; else echo "FAIL: malformed stdin exit $rc"; fail=1; fi

exit $fail
