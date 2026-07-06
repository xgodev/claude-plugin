#!/usr/bin/env bash
# Feeds hook-input JSON to main-folder-guard.sh and asserts deny/allow.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/../dev-rules/main-folder-guard.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }
run() { printf '%s' "$2" | bash "$GUARD"; }

# 1. Guard is OPT-IN: without config, everything is allowed.
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/x.go\"}}")"
if denied "$out"; then echo "FAIL: guard must be opt-in (no config => allow)"; fail=1; else echo "ok  : opt-in -- no config allows"; fi

printf '%s' '{"main_folder_guard": true}' > "$SBX/.dev-rules.json"

# 2. Enabled: Edit/Write in the main working tree is DENIED.
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/src/x.go\"}}")"
if denied "$out"; then echo "ok  : main-tree edit denied"; else echo "FAIL: main-tree edit should be denied"; fail=1; fi
out="$(run Write "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SBX/README.md\"}}")"
if denied "$out"; then echo "ok  : main-tree write denied (docs too)"; else echo "FAIL: main-tree write should be denied"; fail=1; fi

# 3. Targets inside .solvers/ clones are ALLOWED.
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/.solvers/issue-9/src/x.go\"}}")"
if denied "$out"; then echo "FAIL: .solvers edit must be allowed"; fail=1; else echo "ok  : .solvers edit allowed"; fi

# 4. Harness/meta paths stay writable (.dev-rules/, .claude/, outside project).
out="$(run Write "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SBX/.dev-rules/.mode-feature\"}}")"
if denied "$out"; then echo "FAIL: .dev-rules must be writable"; fail=1; else echo "ok  : .dev-rules writable"; fi
out="$(run Write "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SBX/.claude/settings.json\"}}")"
if denied "$out"; then echo "FAIL: .claude must be writable"; fail=1; else echo "ok  : .claude writable"; fi
out="$(run Write '{"tool_name":"Write","tool_input":{"file_path":"/tmp/scratch/x.txt"}}')"
if denied "$out"; then echo "FAIL: outside-project write must be allowed"; fail=1; else echo "ok  : outside-project write allowed"; fi

# 5. Reads are never blocked.
out="$(run Read "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$SBX/src/x.go\"}}")"
if denied "$out"; then echo "FAIL: reads must be allowed"; fail=1; else echo "ok  : reads allowed"; fi

# 6. Bare mutating VCS command in the main folder is DENIED...
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}')"
if denied "$out"; then echo "ok  : bare git commit denied"; else echo "FAIL: bare git commit should be denied"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"git add -A && git push"}}')"
if denied "$out"; then echo "ok  : bare git push denied"; else echo "FAIL: bare git push should be denied"; fail=1; fi
# ...but the same command targeting a .solvers clone is ALLOWED.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"git -C .solvers/issue-9 commit -m x"}}')"
if denied "$out"; then echo "FAIL: git -C .solvers commit must be allowed"; fail=1; else echo "ok  : git -C .solvers commit allowed"; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cd .solvers/issue-9 && git commit -m x"}}')"
if denied "$out"; then echo "FAIL: cd .solvers && git commit must be allowed"; fail=1; else echo "ok  : cd .solvers && git commit allowed"; fi

# 7. Read-only VCS and clone/worktree setup stay allowed in the main folder.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"git status && git log --oneline -3"}}')"
if denied "$out"; then echo "FAIL: read-only git must be allowed"; fail=1; else echo "ok  : read-only git allowed"; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"git worktree add .solvers/issue-9 -b issue-9"}}')"
if denied "$out"; then echo "FAIL: git worktree add must be allowed"; fail=1; else echo "ok  : git worktree add allowed"; fi

# 8. Malformed stdin: clean allow.
printf '%s' 'not-json' | bash "$GUARD" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "ok  : malformed stdin exits 0"; else echo "FAIL: malformed stdin exit $rc"; fail=1; fi

exit $fail
