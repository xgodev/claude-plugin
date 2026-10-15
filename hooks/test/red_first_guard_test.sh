#!/usr/bin/env bash
# Feeds hook-input JSON to red-first-guard.sh and asserts deny/allow.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/../dev-rules/red-first-guard.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }

run() { # tool, json-input
  printf '%s' "$2" | bash "$GUARD"
}

reset() { rm -rf "$SBX/.dev-rules"; }

# 1. No sentinel => bug discipline: reading production is DENIED, and the
# deny message must tell the agent to ASK THE USER which flow applies and
# that the dev may disable the gate (.dev-rules/.off).
reset
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : read prod blocked (bug default)"; else echo "FAIL: read prod should be blocked"; fail=1; fi
if grep -qi 'ask the user' <<<"$out" && grep -q '.dev-rules/.off' <<<"$out"; then
  echo "ok  : read deny questions the user and offers the disable path"
else
  echo "FAIL: read deny must instruct to ask the user and mention .dev-rules/.off"; fail=1
fi

# 1b. No sentinel => EDIT and WRITE of production are DENIED too (bug discipline).
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : edit prod blocked (bug default)"; else echo "FAIL: edit prod should be blocked (no sentinel)"; fail=1; fi
if grep -qi 'ask the user' <<<"$out" && grep -q '.dev-rules/.off' <<<"$out"; then
  echo "ok  : edit deny questions the user and offers the disable path"
else
  echo "FAIL: edit deny must instruct to ask the user and mention .dev-rules/.off"; fail=1
fi
out="$(run Write '{"tool_name":"Write","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : write prod blocked (bug default)"; else echo "FAIL: write prod should be blocked (no sentinel)"; fail=1; fi

# 1c. Bash path (bug default): shell read/write of production is gated too; docs allowed.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cat internal/x.go"}}')"
if denied "$out"; then echo "ok  : bash cat prod blocked"; else echo "FAIL: bash cat prod should block"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"rg foo internal/x.go"}}')"
if denied "$out"; then echo "ok  : bash rg prod blocked"; else echo "FAIL: bash rg prod should block"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"echo x>internal/x.go"}}')"
if denied "$out"; then echo "ok  : bash redirect prod blocked"; else echo "FAIL: bash redirect prod should block"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cat README.md"}}')"
if denied "$out"; then echo "FAIL: bash cat docs should be allowed"; fail=1; else echo "ok  : bash cat docs allowed"; fi

# 2. Test file always allowed (no deny).
reset
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x_test.go"}}')"
if denied "$out"; then echo "FAIL: test file must be allowed"; fail=1; else echo "ok  : test file allowed"; fi

# 3. .mode-feature => reading production allowed.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.mode-feature"
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: feature mode should allow reads"; fail=1; else echo "ok  : feature mode allows reads"; fi
# 3b. A read that redirects stderr (2>&1) must NOT be misread as a write and blocked.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cat src/x.ts 2>&1"}}')"
if denied "$out"; then echo "FAIL: bash read with 2>&1 wrongly blocked in feature mode"; fail=1; else echo "ok  : bash read with 2>&1 allowed (feature mode)"; fi

# 4. .mode-feature => EDIT allowed too (red-first is BUG-only; feature is plan-governed).
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: feature mode should allow edits"; fail=1; else echo "ok  : feature mode allows edits"; fi

# 5. .red-first-unlocked => edit allowed.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.red-first-unlocked"
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: edit must be allowed after RED"; fail=1; else echo "ok  : edit allowed after RED"; fi

# 6. Docs always allowed.
reset
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"README.md"}}')"
if denied "$out"; then echo "FAIL: docs must be allowed"; fail=1; else echo "ok  : docs allowed"; fi

# 6b. Kill switch: .dev-rules/.off disables the gate entirely (read AND edit),
# and survives commits (clear-after-commit never touches it).
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.off"
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: .off must disable read gate"; fail=1; else echo "ok  : .off disables read gate"; fi
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: .off must disable edit gate"; fail=1; else echo "ok  : .off disables edit gate"; fi

# 6c. Kill switch: DEV_RULES_OFF=1 env disables the gate for the session.
reset
out="$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}' | DEV_RULES_OFF=1 bash "$GUARD")"
if denied "$out"; then echo "FAIL: DEV_RULES_OFF=1 must disable gate"; fail=1; else echo "ok  : DEV_RULES_OFF=1 disables gate"; fi

# 7. Absolute paths (Claude Code always sends them for Edit/Write) must match
# relative production_globs from .dev-rules.json -- deny, same as the relative form.
reset
printf '%s' '{"production_globs":["crates/**/src/**"]}' > "$SBX/.dev-rules.json"
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/crates/engine/src/lib.rs\"}}")"
if denied "$out"; then echo "ok  : absolute path matches relative production_globs"; else echo "FAIL: absolute path should match relative production_globs"; fail=1; fi
# 7b. Same file inside an isolated workspace clone (.solvers/<name>/) is production too.
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/.solvers/issue-9/crates/engine/src/lib.rs\"}}")"
if denied "$out"; then echo "ok  : .solvers clone path matches production_globs"; else echo "FAIL: .solvers clone path should match production_globs"; fail=1; fi
rm -f "$SBX/.dev-rules.json"

# 8. Issue #6: directory-scoped Bash reads must NOT bypass file-shaped
# production_globs -- a directory that is a prefix of (or contains) a
# production glob is production too.
reset
mkdir -p "$SBX/crates/engine/src" "$SBX/docs" "$SBX/tests"
printf '%s' '{"production_globs":["crates/**/src/**"]}' > "$SBX/.dev-rules.json"
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"grep -rln foo crates/"}}')"
if denied "$out"; then echo "ok  : grep -r over glob-prefix dir blocked"; else echo "FAIL: grep -rln foo crates/ should be blocked (issue #6)"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"rg foo crates/engine/src/"}}')"
if denied "$out"; then echo "ok  : rg over production dir blocked"; else echo "FAIL: rg foo crates/engine/src/ should be blocked (issue #6)"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"ls crates/engine/src"}}')"
if denied "$out"; then echo "ok  : ls of production dir blocked"; else echo "FAIL: ls crates/engine/src should be blocked (issue #6)"; fail=1; fi
# Non-production directories still pass with the same config.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"grep -r foo docs/"}}')"
if denied "$out"; then echo "FAIL: grep -r docs/ must stay allowed"; fail=1; else echo "ok  : grep -r over docs/ allowed"; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"ls tests/"}}')"
if denied "$out"; then echo "FAIL: ls tests/ must stay allowed"; fail=1; else echo "ok  : ls tests/ allowed"; fi
rm -f "$SBX/.dev-rules.json"

# 9. Issue #26: a sentinel belongs to the workspace the call TARGETS, never to
# a sibling .solvers/<name>/ or the root. A has .mode-feature, B has nothing.
reset; rm -rf "$SBX/.solvers"
mkdir -p "$SBX/.solvers/A/.dev-rules" "$SBX/.solvers/B" "$SBX/.solvers/A/src" "$SBX/.solvers/B/src"
: >"$SBX/.solvers/A/.dev-rules/.mode-feature"
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/.solvers/B/src/x.go\"}}")"
if denied "$out"; then echo "ok  : edit in B denied (sentinel only in A)"; else echo "FAIL: A's sentinel must not unlock an edit in B"; fail=1; fi
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/.solvers/A/src/x.go\"}}")"
if denied "$out"; then echo "FAIL: A's sentinel must unlock an edit in A"; fail=1; else echo "ok  : edit in A allowed by A's sentinel"; fi
out="$(run Read "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$SBX/internal/x.go\"}}")"
if denied "$out"; then echo "ok  : root read denied by A's sentinel"; else echo "FAIL: A's sentinel must not unlock the root"; fail=1; fi
# 9b. A root sentinel does not leak into a workspace either.
mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.mode-feature"
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SBX/.solvers/B/src/x.go\"}}")"
if denied "$out"; then echo "ok  : root sentinel does not unlock B"; else echo "FAIL: a root sentinel must not unlock B"; fail=1; fi
rm -rf "$SBX/.dev-rules"
# 9c. Bash resolves the EFFECTIVE cwd: cd <dir> && ..., git -C <dir>, then .cwd.
out="$(run Bash "{\"tool_name\":\"Bash\",\"cwd\":\"$SBX\",\"tool_input\":{\"command\":\"cd .solvers/A && cat src/x.go\"}}")"
if denied "$out"; then echo "FAIL: cd .solvers/A must use A's sentinel"; fail=1; else echo "ok  : cd .solvers/A uses A's sentinel"; fi
out="$(run Bash "{\"tool_name\":\"Bash\",\"cwd\":\"$SBX\",\"tool_input\":{\"command\":\"cd .solvers/B && cat src/x.go\"}}")"
if denied "$out"; then echo "ok  : cd .solvers/B denied"; else echo "FAIL: cd .solvers/B must not borrow A's sentinel"; fail=1; fi
out="$(run Bash "{\"tool_name\":\"Bash\",\"cwd\":\"$SBX\",\"tool_input\":{\"command\":\"git -C .solvers/A grep foo src/\"}}")"
if denied "$out"; then echo "FAIL: git -C .solvers/A must use A's sentinel"; fail=1; else echo "ok  : git -C .solvers/A uses A's sentinel"; fi
out="$(run Bash "{\"tool_name\":\"Bash\",\"cwd\":\"$SBX/.solvers/A\",\"tool_input\":{\"command\":\"cat src/x.go\"}}")"
if denied "$out"; then echo "FAIL: .cwd inside A must use A's sentinel"; fail=1; else echo "ok  : .cwd inside A uses A's sentinel"; fi
out="$(run Bash "{\"tool_name\":\"Bash\",\"cwd\":\"$SBX/.solvers/B\",\"tool_input\":{\"command\":\"cat src/x.go\"}}")"
if denied "$out"; then echo "ok  : .cwd inside B denied"; else echo "FAIL: .cwd inside B must not borrow A's sentinel"; fail=1; fi
# A root-session path that points into a workspace resolves to that workspace.
out="$(run Bash "{\"tool_name\":\"Bash\",\"cwd\":\"$SBX\",\"tool_input\":{\"command\":\"cat .solvers/A/src/x.go\"}}")"
if denied "$out"; then echo "FAIL: cat .solvers/A/... must use A's sentinel"; fail=1; else echo "ok  : cat .solvers/A/... uses A's sentinel"; fi
rm -rf "$SBX/.solvers"

# 10. Issue #28: an absolute path token OUTSIDE the project (here /src, a path
# inside a container) is not a project file, so it is never production of the
# root workspace. The quality-gate run from an unlocked workspace passes; a
# write to production INSIDE the project still blocks.
bash_in() { # cwd, command -> hook-input JSON
  jq -cn --arg cwd "$1" --arg cmd "$2" '{tool_name:"Bash",cwd:$cwd,tool_input:{command:$cmd}}'
}
reset; rm -rf "$SBX/.solvers"
mkdir -p "$SBX/.solvers/A/.dev-rules" "$SBX/.solvers/A/src" "$SBX/.solvers/B/src"
: >"$SBX/.solvers/A/.dev-rules/.red-first-unlocked"
gate='docker run --rm --pull=always -v "$PWD:/src" -w /src ghcr.io/xgodev/quality-gate/go:latest --format json >"$LOG/result.json"'
out="$(run Bash "$(bash_in "$SBX/.solvers/A" "$gate")")"
if denied "$out"; then echo "FAIL: gate docker run from unlocked A must pass (issue #28)"; fail=1; else echo "ok  : gate docker run from unlocked A allowed"; fi
out="$(run Bash "$(bash_in "$SBX" "cd .solvers/A && $gate")")"
if denied "$out"; then echo "FAIL: cd .solvers/A && gate docker run must pass (issue #28)"; fail=1; else echo "ok  : cd .solvers/A && gate docker run allowed"; fi
out="$(run Bash "$(bash_in "$SBX" 'echo x >/src/x.go')")"
if denied "$out"; then echo "FAIL: write to /src outside the project is not root production (issue #28)"; fail=1; else echo "ok  : absolute token outside the project is not root production"; fi
# Still blocking: production inside the project, relative or absolute.
out="$(run Bash "$(bash_in "$SBX/.solvers/B" "$gate >src/x.go")")"
if denied "$out"; then echo "ok  : redirect into B production denied"; else echo "FAIL: redirect into locked B production must block"; fail=1; fi
out="$(run Bash "$(bash_in "$SBX/.solvers/A" "echo x >$SBX/.solvers/B/src/x.go")")"
if denied "$out"; then echo "ok  : absolute write into B production denied from A"; else echo "FAIL: absolute write into locked B production must block"; fail=1; fi
out="$(run Bash "$(bash_in "$SBX/.solvers/A" "echo x >$SBX/internal/x.go")")"
if denied "$out"; then echo "ok  : absolute write into root production denied from A"; else echo "FAIL: absolute write into locked root production must block"; fail=1; fi
rm -rf "$SBX/.solvers"
# 10b. Same rule for Edit: a file outside the project and every workspace is not
# root production, while a .solvers/<name>/ clone outside the project keeps its
# own sentinel scope (locked without one).
OUT="$(mktemp -d)"
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$OUT/src/x.go\"}}")"
if denied "$out"; then echo "FAIL: edit outside the project is not root production (issue #28)"; fail=1; else echo "ok  : edit outside the project not gated by the root"; fi
out="$(run Edit "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$OUT/.solvers/C/src/x.go\"}}")"
if denied "$out"; then echo "ok  : edit in an outside .solvers/C without sentinel denied"; else echo "FAIL: an outside .solvers/C clone keeps its own lock"; fail=1; fi
rm -rf "$OUT"

# 11. Issue #29: a leading ~ expands to $HOME, as the shell does, both in the
# cd / git -C target and in a path token. HOME is the sandbox here, and .cwd is
# outside it, so an unexpanded ~ can never land on the right workspace.
run_home() { printf '%s' "$1" | HOME="$SBX" bash "$GUARD"; }
reset; rm -rf "$SBX/.solvers"
mkdir -p "$SBX/.solvers/A/.dev-rules" "$SBX/.solvers/A/src" "$SBX/.solvers/B/src"
: >"$SBX/.solvers/A/.dev-rules/.red-first-unlocked"
out="$(run_home "$(bash_in / 'cd ~/.solvers/A && cat src/x.go')")"
if denied "$out"; then echo "FAIL: cd ~/.solvers/A must use A's sentinel (issue #29)"; fail=1; else echo "ok  : cd ~/.solvers/A uses A's sentinel"; fi
out="$(run_home "$(bash_in / 'cd ~ && cat .solvers/A/src/x.go')")"
if denied "$out"; then echo "FAIL: cd ~ && cat .solvers/A/... must use A's sentinel (issue #29)"; fail=1; else echo "ok  : cd ~ resolves to \$HOME"; fi
out="$(run_home "$(bash_in / 'git -C ~/.solvers/A grep foo src/')")"
if denied "$out"; then echo "FAIL: git -C ~/.solvers/A must use A's sentinel (issue #29)"; fail=1; else echo "ok  : git -C ~/.solvers/A uses A's sentinel"; fi
out="$(run_home "$(bash_in / 'cat ~/.solvers/A/src/x.go')")"
if denied "$out"; then echo "FAIL: cat ~/.solvers/A/... must use A's sentinel (issue #29)"; fail=1; else echo "ok  : ~ path token resolves to \$HOME"; fi
# Still blocking: the expanded target is the locked B or the locked root.
out="$(run_home "$(bash_in / 'cd ~/.solvers/B && cat src/x.go')")"
if denied "$out"; then echo "ok  : cd ~/.solvers/B denied"; else echo "FAIL: cd ~/.solvers/B must not borrow A's sentinel"; fail=1; fi
out="$(run_home "$(bash_in / 'cat ~/internal/x.go')")"
if denied "$out"; then echo "ok  : cat ~/internal/x.go (root production) denied"; else echo "FAIL: ~ path token into locked root production must block (issue #29)"; fail=1; fi
rm -rf "$SBX/.solvers"

# Malformed / empty stdin must not crash or block -- clean allow (exit 0, no deny).
printf '%s' 'not-json' | bash "$GUARD" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "ok  : malformed stdin exits 0 (allow)"; else echo "FAIL: malformed stdin exit $rc"; fail=1; fi

exit $fail
