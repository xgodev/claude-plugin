#!/usr/bin/env bash
# Feeds hook-input JSON to push-after-commit-reminder.sh and asserts remind/silent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../dev-rules/push-after-commit-reminder.sh"
fail=0
d="$(mktemp -d)"
git -C "$d" init -q
run() { ( cd "$d" && CLAUDE_PROJECT_DIR="$d" bash "$HOOK" <<<"{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" ); }
reminds() { grep -q '"additionalContext"' <<<"$1" && grep -q 'git push' <<<"$1"; }

out="$(run 'git commit -m x')"
if reminds "$out"; then echo "ok  : commit reminds push"; else echo "FAIL: commit should remind push"; fail=1; fi
out="$(run 'git add a.txt && git -C sub commit -m x')"
if reminds "$out"; then echo "ok  : compound/-C commit reminds"; else echo "FAIL: compound commit should remind"; fail=1; fi
out="$(run 'git commit -m x && git push')"
if [ -z "$out" ]; then echo "ok  : commit+push silent"; else echo "FAIL: commit followed by push must be silent"; fail=1; fi
out="$(run 'git status')"
if [ -z "$out" ]; then echo "ok  : non-commit silent"; else echo "FAIL: non-commit must be silent"; fail=1; fi
touch "$d/.no-op"; mkdir -p "$d/.dev-rules"; touch "$d/.dev-rules/.off"
out="$(run 'git commit -m x')"
if [ -z "$out" ]; then echo "ok  : kill switch silences"; else echo "FAIL: kill switch must silence"; fail=1; fi
rm -rf "$d"
exit "$fail"
