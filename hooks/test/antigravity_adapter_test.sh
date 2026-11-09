#!/usr/bin/env bash
# Test antigravity-adapter.sh: verifies that Antigravity event payloads
# (camelCase protojson with toolCall, workspacePaths, etc.) are translated
# correctly to Claude Code hook inputs, evaluated through the canonical
# hooks/hooks.json definitions, and returned in the Antigravity contract format.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ADAPTER="$ROOT/hooks/antigravity-adapter.sh"
INSTALLER="$ROOT/scripts/install-antigravity.sh"

SBX="$(mktemp -d)"
trap 'rm -rf "$SBX"' EXIT
git -C "$SBX" init -q -b main 2>/dev/null || { git -C "$SBX" init -q && git -C "$SBX" branch -M main; }
git -C "$SBX" config user.email "test@example.com"
git -C "$SBX" config user.name "Test"

fail=0
chk() { if eval "$1"; then echo "ok  : $2"; else echo "FAIL: $2"; fail=1; fi; }

run_adapter() { # event_type, json_payload
  local ev="$1" payload="$2"
  printf '%s' "$payload" | bash "$ADAPTER" "$ev" 2>&1
}

# --- 1. Adapter pre-check ---
chk '[ -f "$ADAPTER" ] && [ -x "$ADAPTER" ]' "antigravity-adapter.sh exists and is executable"
[ -x "$ADAPTER" ] || { echo "Adapter not found or not executable; skipping payload tests"; exit 1; }

# --- 2. PreToolUse: run_command (mapped to Bash) ---
# A git commit on a git_flow protected branch
cat << 'EOF' > "$SBX/.dev-rules.json"
{
  "git_flow": "release-train",
  "git_flow_guard": true
}
EOF
git -C "$SBX" add .dev-rules.json
git -C "$SBX" commit -m "chore: setup" -q

PAYLOAD_COMMIT="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  toolCall: {
    name: "run_command",
    args: {
      CommandLine: "git commit -m \"feat(x): direct commit\""
    }
  }
}')"

out="$(run_adapter PreToolUse "$PAYLOAD_COMMIT")"
chk 'echo "$out" | jq -e ".decision == \"deny\"" >/dev/null 2>&1' "run_command direct commit on main is denied"
chk 'echo "$out" | jq -e ".reason | test(\"git-flow guard\")" >/dev/null 2>&1' "run_command direct commit deny reason cites git-flow guard"

# Non-gated command passes
PAYLOAD_STATUS="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  toolCall: {
    name: "run_command",
    args: {
      CommandLine: "git status"
    }
  }
}')"
out="$(run_adapter PreToolUse "$PAYLOAD_STATUS")"
chk 'echo "$out" | jq -e ".decision == \"allow\"" >/dev/null 2>&1' "run_command git status is allowed"

# --- 3. PreToolUse: read_file (mapped to Read) ---
mkdir -p "$SBX/internal"
echo "package internal" > "$SBX/internal/x.go"
PAYLOAD_READ="$(jq -cn --arg ws "$SBX" --arg p "$SBX/internal/x.go" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  toolCall: {
    name: "read_file",
    args: {
      Path: $p
    }
  }
}')"

# Bug default (no sentinel): production read is denied
out="$(run_adapter PreToolUse "$PAYLOAD_READ")"
chk 'echo "$out" | jq -e ".decision == \"deny\"" >/dev/null 2>&1' "read_file production code locked without sentinel"
chk 'echo "$out" | jq -e ".reason | test(\"dev-rules LAW 13\")" >/dev/null 2>&1' "read_file deny cites dev-rules LAW 13"

# Unlocked with .mode-feature
mkdir -p "$SBX/.dev-rules"
touch "$SBX/.dev-rules/.mode-feature"
out="$(run_adapter PreToolUse "$PAYLOAD_READ")"
chk 'echo "$out" | jq -e ".decision == \"allow\"" >/dev/null 2>&1' "read_file allowed when .mode-feature sentinel present"
rm -f "$SBX/.dev-rules/.mode-feature"

# --- 4. PreToolUse: edit_file (mapped to Edit) ---
PAYLOAD_EDIT="$(jq -cn --arg ws "$SBX" --arg p "$SBX/internal/x.go" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  toolCall: {
    name: "edit_file",
    args: {
      Path: $p,
      Target: "package internal",
      Replacement: "package internal\n// edit"
    }
  }
}')"

# Bug default: edit denied
out="$(run_adapter PreToolUse "$PAYLOAD_EDIT")"
chk 'echo "$out" | jq -e ".decision == \"deny\"" >/dev/null 2>&1' "edit_file production code locked without sentinel"

# Unlocked with .red-first-unlocked
touch "$SBX/.dev-rules/.red-first-unlocked"
out="$(run_adapter PreToolUse "$PAYLOAD_EDIT")"
chk 'echo "$out" | jq -e ".decision == \"allow\"" >/dev/null 2>&1' "edit_file allowed when .red-first-unlocked present"
rm -f "$SBX/.dev-rules/.red-first-unlocked"

# --- 5. PreToolUse: grep_search / find_by_name ---
PAYLOAD_GREP="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  toolCall: {
    name: "grep_search",
    args: {
      SearchPath: ($ws + "/internal"),
      Pattern: "package"
    }
  }
}')"
out="$(run_adapter PreToolUse "$PAYLOAD_GREP")"
chk 'echo "$out" | jq -e ".decision == \"deny\"" >/dev/null 2>&1' "grep_search production directory locked without sentinel"

# --- 6. PostToolUse: commit clears sentinels & buffers notice ---
mkdir -p "$SBX/.dev-rules"
touch "$SBX/.dev-rules/.red-first-unlocked"
touch "$SBX/.dev-rules/.mode-feature"

PAYLOAD_POST_COMMIT="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  stepIdx: 5,
  toolCall: {
    name: "run_command",
    args: {
      CommandLine: "git commit -m \"fix(internal): fix bug\""
    }
  }
}')"

out="$(run_adapter PostToolUse "$PAYLOAD_POST_COMMIT")"
chk '[ "$out" = "{}" ]' "PostToolUse returns {} per Antigravity contract"
chk '[ ! -f "$SBX/.dev-rules/.red-first-unlocked" ]' "PostToolUse cleared .red-first-unlocked"
chk '[ ! -f "$SBX/.dev-rules/.mode-feature" ]' "PostToolUse cleared .mode-feature"
chk '[ -f "$SBX/.dev-rules/.agy-pending-notices" ]' "PostToolUse buffered reminder notices"

# --- 7. PostInvocation: drains buffered notices ---
PAYLOAD_POST_INVOCATION="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws]
}')"

out="$(run_adapter PostInvocation "$PAYLOAD_POST_INVOCATION")"
chk 'echo "$out" | jq -e ".injectSteps[0].ephemeralMessage | test(\"re-armed\")" >/dev/null 2>&1' "PostInvocation emits buffered re-armed notice"
chk '[ ! -f "$SBX/.dev-rules/.agy-pending-notices" ]' "PostInvocation cleaned up .agy-pending-notices"

# PostInvocation with empty notices returns {}
out="$(run_adapter PostInvocation "$PAYLOAD_POST_INVOCATION")"
chk '[ "$out" = "{}" ]' "PostInvocation with no notices returns {}"

# --- 8. SessionStart: announces LAW 42 in git repo ---
PAYLOAD_SESSION="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws]
}')"
out="$(run_adapter SessionStart "$PAYLOAD_SESSION")"
chk 'echo "$out" | jq -e ".injectSteps[0].systemMessage.systemMessage | test(\"LAW 42\")" >/dev/null 2>&1' "SessionStart injects systemMessage with LAW 42"

# --- 9. PreInvocation: announces LAW 13 when no mode set ---
PAYLOAD_PRE_INVOCATION="$(jq -cn --arg ws "$SBX" '{
  conversationId: "test-conv-1",
  workspacePaths: [$ws],
  invocationNum: 1
}')"
out="$(run_adapter PreInvocation "$PAYLOAD_PRE_INVOCATION")"
chk 'echo "$out" | jq -e ".injectSteps[0].ephemeralMessage | test(\"LAW 13\")" >/dev/null 2>&1' "PreInvocation injects ephemeralMessage with LAW 13 when no mode set"

# Mode set -> silent
touch "$SBX/.dev-rules/.mode-feature"
out="$(run_adapter PreInvocation "$PAYLOAD_PRE_INVOCATION")"
chk '[ "$out" = "{}" ]' "PreInvocation is silent when mode is set"
rm -f "$SBX/.dev-rules/.mode-feature"

# --- 10. Fail-open on invalid input ---
out="$(run_adapter PreToolUse "invalid-json")"
chk 'echo "$out" | jq -e ".decision == \"allow\"" >/dev/null 2>&1' "PreToolUse fails open (allow) on malformed json"

# --- 11. Installer check ---
chk '[ -f "$INSTALLER" ] && [ -x "$INSTALLER" ]' "install-antigravity.sh exists and is executable"
if [ -x "$INSTALLER" ]; then
  chk 'bash "$INSTALLER" --help >/dev/null 2>&1' "installer --help works"
  chk '! bash "$INSTALLER" --invalid-flag >/dev/null 2>&1' "installer rejects unknown flags"

  TEST_PROJ="$SBX/test-proj"
  mkdir -p "$TEST_PROJ"
  bash "$INSTALLER" --project "$TEST_PROJ" >/dev/null 2>&1
  chk '[ -d "$TEST_PROJ/.agents/plugins/claude-plugin" ]' "installer creates project plugin directory"
  chk '[ -f "$TEST_PROJ/.agents/plugins/claude-plugin/.antigravity-plugin/plugin.json" ] || [ -f "$TEST_PROJ/.agents/plugins/claude-plugin/plugin.json" ]' "installed project plugin has plugin manifest"
  chk '[ -f "$TEST_PROJ/.agents/plugins/claude-plugin/hooks.json" ]' "installed project plugin has hooks.json"

  bash "$INSTALLER" --uninstall --project "$TEST_PROJ" >/dev/null 2>&1
  chk '[ ! -d "$TEST_PROJ/.agents/plugins/claude-plugin" ]' "installer cleanly uninstalls project plugin"
fi

# --- 12. agy plugin validate ---
if command -v agy >/dev/null 2>&1; then
  out="$(agy plugin validate "$ROOT" --json 2>&1)"
  rc=$?
  chk '[ "$rc" -eq 0 ]' "agy plugin validate passes on repo root with 0 errors"
  err_count="$(echo "$out" | jq '[.findings[] | select(.severity == "error")] | length' 2>/dev/null || echo 0)"
  chk '[ "$err_count" -eq 0 ]' "agy plugin validate reports 0 errors"
fi

exit $fail
