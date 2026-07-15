#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
J="$HERE/../hooks.json"
fail=0
chk() { if eval "$1"; then echo "ok  : $2"; else echo "FAIL: $2"; fail=1; fi; }

chk '[ -f "$J" ]' "hooks.json exists"
chk 'jq -e . "$J" >/dev/null 2>&1' "hooks.json is valid JSON"
pre_wires() { jq -e "[.hooks.PreToolUse[].hooks[].command] | any(test(\"$1\"))" "$J" >/dev/null 2>&1; }
chk 'pre_wires "red-first-guard.sh"' "PreToolUse wires red-first-guard.sh"
chk 'jq -e "[.hooks.PostToolUse[].hooks[].command] | any(test(\"clear-after-commit.sh\"))" "$J" >/dev/null 2>&1' "PostToolUse wires clear-after-commit.sh"
chk 'jq -e "[.hooks.PostToolUse[].hooks[].command] | any(test(\"issue-comment-reminder.sh\"))" "$J" >/dev/null 2>&1' "PostToolUse wires issue-comment-reminder.sh"
chk 'jq -e "[.hooks.UserPromptSubmit[].hooks[].command] | any(test(\"mode-prompt.sh\"))" "$J" >/dev/null 2>&1' "UserPromptSubmit wires mode-prompt.sh"
P="$HERE/../../.claude-plugin/plugin.json"
chk '! jq -e ".hooks" "$P" >/dev/null 2>&1' "plugin.json declares NO hooks key (double registration breaks the plugin)"
chk 'pre_wires "main-folder-guard.sh"' "PreToolUse wires main-folder-guard.sh"
chk 'pre_wires "line-cap-guard.sh"' "PreToolUse wires line-cap-guard.sh"
chk 'pre_wires "pr-gate.sh"' "PreToolUse wires pr-gate.sh"
chk 'grep -q "CLAUDE_PLUGIN_ROOT" "$J"' "uses CLAUDE_PLUGIN_ROOT path var"
exit $fail
