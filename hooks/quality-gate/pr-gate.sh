#!/usr/bin/env bash
# pr-gate.sh -- PreToolUse hook (quality-gate plugin).
# Blocks `gh pr create` unless the gate passes for HEAD. The gate belongs to
# the PR moment (and CI) -- `git push` is NEVER gated: pushing work-in-progress
# must stay cheap, and on a heavy project a per-push gate costs minutes.
# English only. Fails OPEN on its own errors: a broken hook must never
# brick the user's git.

set -uo pipefail

input="$(cat)"

# jq is required to parse the tool input; without it, fail open.
if ! command -v jq >/dev/null 2>&1; then
  echo "qg-hook: jq not found; skipping gate enforcement" >&2
  exit 0
fi

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0   # not a readable Bash command -> allow

# --- decide whether a gated operation is present ---------------------------
# Match `gh pr create` as the leading tokens of any &&/||/;/| segment (not a
# bare substring), after stripping leading env assignments (FOO=bar cmd).
should_gate=0
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//')"
  case "$seg" in
    "gh pr create"|"gh pr create "*) should_gate=1 ;;
  esac
done <<< "$(printf '%s' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')"

[ "$should_gate" -eq 1 ] || exit 0

# --- locate project -------------------------------------------------------
proj="${CLAUDE_PROJECT_DIR:-$PWD}"
root="$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null)" || exit 0  # not a repo -> allow

# The gate is a Docker image (xgodev/quality-gate). Docker absent -> fail open:
# a missing runtime must never brick the user's git.
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "qg-hook: docker unavailable; skipping gate enforcement" >&2
  exit 0
fi

# --- pick the per-language image by root sentinel -------------------------
lang=""
if   [ -f "$root/Cargo.toml" ]; then lang=rust
elif [ -f "$root/go.mod" ]; then lang=go
elif [ -f "$root/pom.xml" ]; then lang=java
elif [ -f "$root/build.gradle" ] || [ -f "$root/build.gradle.kts" ]; then lang=kotlin
elif [ -f "$root/Package.swift" ]; then lang=swift
elif [ -f "$root/pyproject.toml" ] || [ -f "$root/setup.py" ] || [ -f "$root/requirements.txt" ]; then lang=python
elif [ -f "$root/package.json" ]; then lang=nodejs
elif ls "$root"/*.html "$root"/*.css >/dev/null 2>&1; then lang=web
fi
[ -z "$lang" ] && exit 0   # no supported language -> allow

image="${QG_IMAGE:-ghcr.io/xgodev/quality-gate/${lang}:${QG_TAG:-latest}}"

# --- resolve base ref (upstream -> origin default -> absolute) ------------
base="$(git -C "$proj" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [ -z "$base" ]; then
  base="$(git -C "$proj" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
fi

# --- run the gate in the container ----------------------------------------
logs="$(mktemp -d "${TMPDIR:-/tmp}/qg-hook-XXXXXX")"
# QG_PULL (default always): the tag is moving (`latest`), so refresh it every
# run -- a cached copy would silently gate against a stale gate. A pull failure
# -> rc 125 -> fail open below. Gate developers testing a locally built image
# set QG_PULL=never.
pull="${QG_PULL:-always}"
# QG_PLATFORM: force a platform (e.g. linux/amd64) when the image has no variant
# for the host arch -- a native run then fails with "no matching manifest".
plat="${QG_PLATFORM:+--platform $QG_PLATFORM}"
run_gate() { docker run --rm "--pull=$pull" $plat -v "$root:/src" -w /src -v "$logs:/logs" "$image" --log-dir /logs "$@" 2>&1; }
if [ -n "$base" ]; then
  out="$(run_gate --base "$base")"; rc=$?
else
  out="$(run_gate)"; rc=$?   # absolute mode
fi
rm -rf "$logs"

# Image not pulled / pull denied / daemon hiccup -> docker exit 125/126/127.
# Fail open: enforcement is best-effort locally, CI is the hard gate.
case "$rc" in
  125|126|127) echo "qg-hook: image '$image' unavailable (docker rc $rc); skipping" >&2; exit 0 ;;
esac

# --- map exit code to decision --------------------------------------------
case "$rc" in
  0|3) exit 0 ;;   # passed / bypassed / no-language -> allow
esac

verdict="regressed/failed"
[ "$rc" -eq 2 ] && verdict="tool error"
tail_out="$(printf '%s' "$out" | tail -n 6 | tr '\n' ' ')"
reason="Quality gate ${verdict} (qg exit ${rc}). ${tail_out} -- run the gate and fix, or set QG_BYPASS_REASON to override."

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
