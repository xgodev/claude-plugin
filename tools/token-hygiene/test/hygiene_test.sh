#!/usr/bin/env bash
# Builds a sandbox installation with one of each problem and asserts every
# check finds it, then asserts a clean sandbox reports nothing.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYGIENE="$HERE/../hygiene"
SBX="$(mktemp -d)"
trap 'rm -rf "$SBX"' EXIT
fail=0

check() { # name needle output
  if grep -q "$2" <<<"$3"; then echo "ok  : $1"; else echo "FAIL: $1"; fail=1; fi
}

home="$SBX/home/.claude"
roots="$SBX/code"
mkdir -p "$home/projects/demo/memory" "$home/plugins/marketplaces/acme/.claude-plugin" \
         "$home/plugins/cache/acme/acme/1.0.0/.claude-plugin" "$roots/app/.claude"

# An index far over the limit, carried into every session.
head -c 9000 /dev/zero | tr '\0' 'x' > "$home/projects/demo/memory/MEMORY.md"

# superpowers on in a project that has not dispatched anything. Enabled is
# fine; enabled and idle is the finding.
printf '{}' > "$home/settings.json"
printf '{"enabledPlugins":{"superpowers@official":true}}' > "$roots/app/.claude/settings.json"

# ... and on in a project that uses it, which must stay silent.
mkdir -p "$roots/busy/.claude"
printf '{"enabledPlugins":{"superpowers@official":true}}' > "$roots/busy/.claude/settings.json"
busy_slug="$(printf '%s' "$roots/busy" | tr -c 'A-Za-z0-9' '-')"
mkdir -p "$home/projects/$busy_slug"
printf '{"timestamp":"2099-01-01T00:00:00Z","message":{"content":[{"type":"tool_use","name":"Agent"}]}}\n' \
  > "$home/projects/$busy_slug/s.jsonl"

# The same MCP server declared by the user config and by a plugin.
printf '{"mcpServers":{"dup":{"url":"x"}}}' > "$SBX/home/.claude.json"
printf '{"mcpServers":{"dup":{"url":"x"}}}' > "$home/plugins/cache/acme/acme/1.0.0/.mcp.json"

# A cache that drifted from the source version it claims to be.
printf '{"name":"acme","version":"1.0.0"}' > "$home/plugins/marketplaces/acme/.claude-plugin/plugin.json"
printf '{"name":"acme","version":"1.0.0","extra":1}' > "$home/plugins/cache/acme/acme/1.0.0/.claude-plugin/plugin.json"

# Today's spend: a main session with a huge context per request, plus a
# subagent transcript that outweighs it. Streaming repeats one message on
# several lines; it must be counted once.
today="$(date -u +%Y-%m-%dT12:00:00Z)"
mkdir -p "$home/projects/demo/s1/subagents"
u='"usage":{"input_tokens":10,"cache_read_input_tokens":300000,"cache_creation_input_tokens":0}'
printf '{"timestamp":"%s","message":{"id":"m1",%s}}\n' "$today" "$u" "$today" "$u" > "$home/projects/demo/s1.jsonl"
printf '{"timestamp":"%s","isSidechain":true,"message":{"id":"a%s",%s}}\n' \
  "$today" 1 "$u" "$today" 2 "$u" "$today" 3 "$u" > "$home/projects/demo/s1/subagents/agent-x.jsonl"

out="$(CLAUDE_HOME="$home" "$HYGIENE" --roots "$roots" 2>&1)"

check "memory: oversized index"      "MEMORY.md is 9000B"              "$out"
check "dispatch: enabled and idle"   "app: superpowers@official is ON but nothing was dispatched" "$out"
if grep -q "busy:" <<<"$out"; then echo "FAIL: a project that uses dispatch must not be reported"; fail=1; else echo "ok  : enabled and used is silent"; fi
check "mcp: duplicate server"        "MCP server 'dup' declared 2x"    "$out"
check "plugin-cache: drift"          "acme/acme 1.0.0"                 "$out"
check "usage: subagent share"      "subagents were 75% of"           "$out"
check "usage: context per request"   "300k tokens of context per request" "$out"
check "usage: streaming counted once" "1.2M tokens" "$out"

# A sandbox with nothing wrong must say so, or the report is noise nobody reads.
clean="$SBX/clean"; mkdir -p "$clean/.claude/projects" "$clean/code"
printf '{}' > "$clean/.claude/settings.json"
out="$(CLAUDE_HOME="$clean/.claude" "$HYGIENE" --roots "$clean/code" 2>&1)"
check "clean installation is silent" "^clean - nothing to do.$" "$out"

# --fix must be the only way anything is written.
before="$(cat "$home/plugins/cache/acme/acme/1.0.0/.claude-plugin/plugin.json")"
CLAUDE_HOME="$home" "$HYGIENE" --roots "$roots" plugin-cache >/dev/null 2>&1
after="$(cat "$home/plugins/cache/acme/acme/1.0.0/.claude-plugin/plugin.json")"
if [ "$before" = "$after" ]; then echo "ok  : audit does not write"; else echo "FAIL: audit wrote without --fix"; fail=1; fi

CLAUDE_HOME="$home" "$HYGIENE" --roots "$roots" --fix plugin-cache >/dev/null 2>&1
fixed="$(cat "$home/plugins/cache/acme/acme/1.0.0/.claude-plugin/plugin.json")"
if [ "$fixed" = '{"name":"acme","version":"1.0.0"}' ]; then echo "ok  : --fix refreshes the cache"; else echo "FAIL: --fix did not refresh the cache"; fail=1; fi

exit "$fail"
