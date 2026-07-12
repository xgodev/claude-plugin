#!/usr/bin/env bash
# Feeds hook-input JSON to issue-comment-reminder.sh and asserts remind/silent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../dev-rules/issue-comment-reminder.sh"
fail=0
reminds() { grep -q '"additionalContext"' <<<"$1" && grep -q "issue #$2" <<<"$1"; }
run_in() { # repo-dir, json
  ( cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$HOOK" <<<"$2" )
}
mkrepo() { # branch-name
  local d; d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$d" checkout -qb "$1" 2>/dev/null || git -C "$d" checkout -q "$1"
  echo "$d"
}

# 1. push on an issue branch -> reminder with the issue number.
d="$(mkrepo feature/issue-42)"
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"git push origin HEAD"}}')"
if reminds "$out" 42; then echo "ok  : issue branch push reminds #42"; else echo "FAIL: should remind issue 42"; fail=1; fi
# 1b. compound and env-prefixed pushes also remind.
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"git add -A && git push -u origin feature/issue-42"}}')"
if reminds "$out" 42; then echo "ok  : compound push reminds"; else echo "FAIL: compound push should remind"; fail=1; fi
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"A=b git push --no-verify"}}')"
if reminds "$out" 42; then echo "ok  : env-prefixed push reminds"; else echo "FAIL: env-prefixed push should remind"; fail=1; fi
rm -rf "$d"

# 2. bugfix/issue-7 convention also matches.
d="$(mkrepo bugfix/issue-7)"
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"git push"}}')"
if reminds "$out" 7; then echo "ok  : bugfix/issue-7 reminds #7"; else echo "FAIL: bugfix/issue-7 should remind"; fail=1; fi
rm -rf "$d"

# 3. non-issue branch -> silent.
d="$(mkrepo main)"
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"git push"}}')"
if [ -z "$out" ]; then echo "ok  : non-issue branch silent"; else echo "FAIL: non-issue branch must be silent"; fail=1; fi

# 4. non-push command -> silent.
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"git status"}}')"
if [ -z "$out" ]; then echo "ok  : non-push silent"; else echo "FAIL: non-push must be silent"; fail=1; fi
rm -rf "$d"

# 5. not a git repo -> silent, exit 0.
d="$(mktemp -d)"
out="$(run_in "$d" '{"tool_name":"Bash","tool_input":{"command":"git push"}}')"; rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then echo "ok  : non-repo silent"; else echo "FAIL: non-repo must be silent exit 0"; fail=1; fi
rm -rf "$d"

# 6. kill switch: DEV_RULES_OFF=1 silences the reminder too.
d="$(mkrepo feature/issue-9)"
out="$( ( cd "$d" && CLAUDE_PROJECT_DIR="$d" DEV_RULES_OFF=1 bash "$HOOK" <<<'{"tool_name":"Bash","tool_input":{"command":"git push"}}' ) )"
if [ -z "$out" ]; then echo "ok  : DEV_RULES_OFF silences reminder"; else echo "FAIL: kill switch must silence"; fail=1; fi
rm -rf "$d"

# 7. malformed stdin -> exit 0.
printf '%s' 'not-json' | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "ok  : malformed stdin exits 0"; else echo "FAIL: malformed stdin exit $rc"; fail=1; fi

exit $fail
