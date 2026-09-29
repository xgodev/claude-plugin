#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../dev-rules/clear-after-commit.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0

arm()     { mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.red-first-unlocked"; : >"$SBX/.dev-rules/.mode-feature"; }
cleared() { [ ! -f "$SBX/.dev-rules/.red-first-unlocked" ] && [ ! -f "$SBX/.dev-rules/.mode-feature" ]; }
intact()  { [ -f "$SBX/.dev-rules/.red-first-unlocked" ] && [ -f "$SBX/.dev-rules/.mode-feature" ]; }
# set -e aborts if the hook itself crashes (never a false "ok").
fire()    { printf '%s' "$1" | bash "$HOOK" >/dev/null; }
cj()      { printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"%s\\""},"tool_response":%s}' "$1" "$2"; }

# Every clearing pattern must clear BOTH sentinels on a successful commit.
for msg in "feat(x): y" "fix(x): y" "bugfix(x): y" "Fix #12 y" "Fixes #12 y"; do
  arm; fire "$(cj "$msg" '{"exit_code":0}')"
  if cleared; then echo "ok  : cleared on [$msg]"; else echo "FAIL: should clear on [$msg]"; fail=1; fi
done

# Non-clearing: chore/docs commit leaves both sentinels.
arm; fire "$(cj "docs: y" '{"exit_code":0}')"
if intact; then echo "ok  : docs left sentinels"; else echo "FAIL: docs must not clear"; fail=1; fi

# Non-clearing: failed commit by exit_code leaves both.
arm; fire "$(cj "fix(x): y" '{"exit_code":1}')"
if intact; then echo "ok  : failed (exit_code) left sentinels"; else echo "FAIL: failed exit_code must not clear"; fail=1; fi

# Non-clearing: failed commit reported as {"success":false} leaves both
# (guards the jq // -false trap: false must not be read as "absent"->success).
arm; fire "$(cj "fix(x): y" '{"success":false}')"
if intact; then echo "ok  : failed (success:false) left sentinels"; else echo "FAIL: success:false must not clear"; fail=1; fi

# Issue #26: a commit re-arms ONLY the workspace it ran in.
armws()  { mkdir -p "$SBX/$1/.dev-rules"; : >"$SBX/$1/.dev-rules/.red-first-unlocked"; : >"$SBX/$1/.dev-rules/.mode-feature"; }
has()    { [ -f "$SBX/$1/.dev-rules/.red-first-unlocked" ] && [ -f "$SBX/$1/.dev-rules/.mode-feature" ]; }
none()   { [ ! -f "$SBX/$1/.dev-rules/.red-first-unlocked" ] && [ ! -f "$SBX/$1/.dev-rules/.mode-feature" ]; }
cjc()    { printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"},"tool_response":{"exit_code":0}}' "$1" "$2"; }
armall() { arm; armws .solvers/A; armws .solvers/B; }

armall; fire "$(cjc "$SBX" 'cd .solvers/A && git commit -m \"feat(x): y\"')"
if none .solvers/A && has .solvers/B && intact; then echo "ok  : cd A commit clears only A"; else echo "FAIL: cd A commit must clear A and leave B and root"; fail=1; fi

armall; fire "$(cjc "$SBX" 'git -C .solvers/B commit -m \"fix(x): y\"')"
if none .solvers/B && has .solvers/A && intact; then echo "ok  : git -C B commit clears only B"; else echo "FAIL: git -C B commit must clear B only"; fail=1; fi

armall; fire "$(cjc "$SBX/.solvers/A" 'git commit -m \"feat(x): y\"')"
if none .solvers/A && has .solvers/B && intact; then echo "ok  : .cwd A commit clears only A"; else echo "FAIL: .cwd A commit must clear A only"; fail=1; fi

armall; fire "$(cjc "$SBX" 'git commit -m \"feat(x): y\"')"
if cleared && has .solvers/A && has .solvers/B; then echo "ok  : root commit leaves workspaces"; else echo "FAIL: root commit must not touch .solvers sentinels"; fail=1; fi
rm -rf "$SBX/.solvers"

exit $fail
