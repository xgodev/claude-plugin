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
chk 'jq -e "[.hooks.PostToolUse[].hooks[].command] | any(test(\"push-after-commit-reminder.sh\"))" "$J" >/dev/null 2>&1' "PostToolUse wires push-after-commit-reminder.sh"
chk 'jq -e "[.hooks.UserPromptSubmit[].hooks[].command] | any(test(\"mode-prompt.sh\"))" "$J" >/dev/null 2>&1' "UserPromptSubmit wires mode-prompt.sh"
chk 'jq -e "[.hooks.SessionStart[].hooks[].command] | any(test(\"unrelated-work-reminder.sh\"))" "$J" >/dev/null 2>&1' "SessionStart wires unrelated-work-reminder.sh"
P="$HERE/../../.claude-plugin/plugin.json"
chk '! jq -e ".hooks" "$P" >/dev/null 2>&1' "plugin.json declares NO hooks key (double registration breaks the plugin)"
chk 'pre_wires "main-folder-guard.sh"' "PreToolUse wires main-folder-guard.sh"
chk 'pre_wires "line-cap-guard.sh"' "PreToolUse wires line-cap-guard.sh"
chk 'pre_wires "git-flow-guard.sh"' "PreToolUse wires git-flow-guard.sh"
chk 'pre_wires "pr-gate.sh"' "PreToolUse wires pr-gate.sh"
chk 'grep -q "CLAUDE_PLUGIN_ROOT" "$J"' "uses CLAUDE_PLUGIN_ROOT path var"

# Antigravity dual-target contracts
ROOT="$HERE/../.."
AGY_HOOKS="$ROOT/hooks.json"
AGY_MANIFEST="$ROOT/.antigravity-plugin/plugin.json"
ADAPTER="$ROOT/hooks/antigravity-adapter.sh"

chk '[ -f "$AGY_HOOKS" ]' "root hooks.json exists"
chk 'jq -e . "$AGY_HOOKS" >/dev/null 2>&1' "root hooks.json is valid JSON"
chk 'jq -e ".[].PreToolUse // empty" "$AGY_HOOKS" >/dev/null 2>&1' "root hooks.json declares PreToolUse"
chk 'jq -e ".[].PostToolUse // empty" "$AGY_HOOKS" >/dev/null 2>&1' "root hooks.json declares PostToolUse"
chk 'jq -e ".[].SessionStart // empty" "$AGY_HOOKS" >/dev/null 2>&1' "root hooks.json declares SessionStart"
chk 'jq -e ".[].PreInvocation // empty" "$AGY_HOOKS" >/dev/null 2>&1' "root hooks.json declares PreInvocation"
chk 'jq -e ".[].PostInvocation // empty" "$AGY_HOOKS" >/dev/null 2>&1' "root hooks.json declares PostInvocation"
chk 'grep -q "antigravity-adapter.sh" "$AGY_HOOKS"' "root hooks.json routes through antigravity-adapter.sh"

chk '[ -f "$AGY_MANIFEST" ]' ".antigravity-plugin/plugin.json exists"
chk 'jq -e . "$AGY_MANIFEST" >/dev/null 2>&1' ".antigravity-plugin/plugin.json is valid JSON"
chk '[ "$(jq -r .version "$P")" = "$(jq -r .version "$AGY_MANIFEST" 2>/dev/null)" ]' "plugin.json versions match between Claude and Antigravity manifests"
chk '[ "$(jq -r .name "$P")" = "$(jq -r .name "$AGY_MANIFEST" 2>/dev/null)" ]' "plugin.json names match between Claude and Antigravity manifests"
chk '! jq -e ".dependencies" "$AGY_MANIFEST" >/dev/null 2>&1' ".antigravity-plugin/plugin.json declares NO dependencies (Antigravity ignores/warns)"
chk 'LOGO="$(jq -r .logo "$AGY_MANIFEST" 2>/dev/null)" && [ -n "$LOGO" ] && [ -f "$ROOT/$LOGO" ]' ".antigravity-plugin/plugin.json logo exists"

chk '[ -f "$ADAPTER" ] && [ -x "$ADAPTER" ]' "hooks/antigravity-adapter.sh exists and is executable"

exit $fail
