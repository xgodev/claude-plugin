# Enforcement hook (PR quality gate)

The plugin ships an **opt-in** `PreToolUse` hook that blocks `gh pr create`
unless the quality gate passes for the current HEAD.

**`git push` is NEVER gated.** The gate belongs to the PR moment (and to
CI): pushing work-in-progress must stay cheap, and on a heavy project a
per-push gate costs minutes. Enforce the same gate in CI for the hard,
server-side guarantee.

## What it does

On any `Bash` tool call, `hooks/quality-gate/pr-gate.sh` runs. It fast-exits
for everything except `gh pr create` (matched as the leading tokens of a
command segment, not as a substring). For a gated command it:

1. Resolves the base ref: the branch upstream (`@{upstream}`), else the remote
   default branch (`origin/HEAD`), else **absolute mode** (no base).
2. Runs `${CLAUDE_PLUGIN_ROOT}/tools/quality-gate/qg [--base <ref>]` in the
   project.
3. Maps the gate exit code to a decision:
   - `0` passed / bypassed, `3` no supported language -> **allow**
   - `1` regressed / threshold, `2` tool error -> **deny** (JSON
     `permissionDecision: "deny"` with a concise reason)

## Bypass

The hook adds no bypass logic of its own. Exporting `QG_BYPASS_REASON` (already
honored by every gate, and audit-logged) makes the gate return `0`, so the PR
is allowed. Example:

    QG_BYPASS_REASON="hotfix: gate infra down, reviewed manually" gh pr create

## Fail-open by design

A broken hook must never brick the user's git. If `jq` is missing, stdin is
malformed, `qg` is not found at `${CLAUDE_PLUGIN_ROOT}/tools/quality-gate`, or
the project is not a git repo, the hook allows the command and prints a note
to stderr.

## Registration

Declared in `hooks/hooks.json` (matcher `Bash`), which Claude Code loads
**automatically** because it sits at the plugin's standard hooks path. The
plugin manifest must NOT also reference it: a `"hooks": "./hooks/hooks.json"`
key in `.claude-plugin/plugin.json` duplicates the auto-loaded file and makes
the whole plugin fail to load (`manifest.hooks` is only for *additional*,
non-standard hook files). The script locates the gate through
`${CLAUDE_PLUGIN_ROOT}` and the project through `${CLAUDE_PROJECT_DIR}`.

## Known limitations

This hook is **advisory enforcement**, not a hard security boundary: it is
opt-in and it fails open. Detection keys on the leading tokens of each command
segment, so uncommon forms (a subshell-wrapped or `eval`-ed `gh pr create`)
are not gated. For a gate that cannot be sidestepped, enforce `qg` in CI --
the hook is a fast local check, not a replacement for a server-side gate.
