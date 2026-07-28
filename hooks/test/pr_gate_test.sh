#!/usr/bin/env bash
# Feeds hook-input JSON to pr-gate.sh and asserts the per-project opt-out
# (.qg-hook.json). Docker is shadowed by a stub so the hook never pulls/runs a
# real image: when the gate stays ON it falls through to the "docker
# unavailable" fail-open branch, so the two outcomes are told apart by stderr.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../quality-gate/pr-gate.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
git -C "$SBX" init -q
# Shadow docker with a stub that always fails `docker info` -> the ON path
# reports "docker unavailable" instead of touching the network.
mkdir -p "$SBX/bin"; printf '#!/bin/sh\nexit 1\n' > "$SBX/bin/docker"; chmod +x "$SBX/bin/docker"
export PATH="$SBX/bin:$PATH"
fail=0
PR='{"tool_name":"Bash","tool_input":{"command":"gh pr create"}}'
# runs the hook, leaving combined output in $out and the exit code in $rc
run() { out="$(printf '%s' "$PR" | bash "$HOOK" 2>&1)"; rc=$?; }
disabled() { grep -q "PR-gate disabled for '$1'" <<<"$2"; }

cfg() { printf '%s' "$1" > "$SBX/.qg-hook.json"; }
sentinel_rust() { rm -f "$SBX/go.mod"; printf '[package]\nname="x"\n' > "$SBX/Cargo.toml"; }
sentinel_go()   { rm -f "$SBX/Cargo.toml"; printf 'module x\n' > "$SBX/go.mod"; }

# 1. Per-language off: rust project + {"pr_gate":{"rust":false}} -> skipped.
sentinel_rust; cfg '{"pr_gate":{"rust":false}}'; run
if [ "$rc" = 0 ] && disabled rust "$out"; then echo "ok  : rust opt-out skips the gate"; else echo "FAIL: rust opt-out should skip (rc=$rc): $out"; fail=1; fi

# 2. Language mismatch: go project + {"pr_gate":{"rust":false}} -> gate stays ON.
sentinel_go; cfg '{"pr_gate":{"rust":false}}'; run
if disabled go "$out" || disabled rust "$out"; then echo "FAIL: go must stay gated when only rust is disabled: $out"; fail=1; else echo "ok  : go stays gated (rust-only opt-out)"; fi

# 3. Global boolean off: rust project + {"pr_gate":false} -> skipped.
sentinel_rust; cfg '{"pr_gate":false}'; run
if [ "$rc" = 0 ] && disabled rust "$out"; then echo "ok  : global pr_gate:false skips the gate"; else echo "FAIL: global off should skip (rc=$rc): $out"; fail=1; fi

# 4. Broken JSON -> fail-safe, gate stays ON (never parsed as a waiver).
sentinel_rust; cfg '{not json'; run
if disabled rust "$out"; then echo "FAIL: broken .qg-hook.json must NOT disable the gate: $out"; fail=1; else echo "ok  : broken JSON leaves the gate ON"; fi

# 5. Key absent (value not false) -> gate stays ON.
sentinel_rust; cfg '{"pr_gate":{"rust":true}}'; run
if disabled rust "$out"; then echo "FAIL: pr_gate.rust:true must NOT disable the gate: $out"; fail=1; else echo "ok  : rust:true leaves the gate ON"; fi

# 6. No config file at all -> gate stays ON.
sentinel_rust; rm -f "$SBX/.qg-hook.json"; run
if disabled rust "$out"; then echo "FAIL: no config must NOT disable the gate: $out"; fail=1; else echo "ok  : no config leaves the gate ON"; fi

exit $fail
