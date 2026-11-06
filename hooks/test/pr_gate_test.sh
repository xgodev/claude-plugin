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
# Shadow docker with a stub that can simulate docker availability and worktree volume checks.
mkdir -p "$SBX/bin"
cat << 'EOF' > "$SBX/bin/docker"
#!/usr/bin/env bash
if [ "$1" = "info" ]; then
  if [ "${MOCK_DOCKER_AVAILABLE:-0}" = "1" ]; then
    exit 0
  fi
  exit 1
fi
if [ "$1" = "run" ]; then
  if [ -n "${MOCK_DOCKER_LOG:-}" ]; then
    echo "$@" >> "$MOCK_DOCKER_LOG"
  fi
  if [ -n "${MOCK_EXPECT_COMMON_DIR:-}" ]; then
    found_vol=0
    for arg in "$@"; do
      if [ "$arg" = "-v" ]; then
        prev_v=1
      elif [ "${prev_v:-0}" = "1" ]; then
        prev_v=0
        if [ "$arg" = "$MOCK_EXPECT_COMMON_DIR:$MOCK_EXPECT_COMMON_DIR" ]; then
          found_vol=1
        fi
      elif [[ "$arg" == "-v$MOCK_EXPECT_COMMON_DIR:$MOCK_EXPECT_COMMON_DIR" ]] || [[ "$arg" == "--volume=$MOCK_EXPECT_COMMON_DIR:$MOCK_EXPECT_COMMON_DIR" ]]; then
        found_vol=1
      fi
    done
    if [ "$found_vol" -eq 0 ]; then
      echo "fatal: not a git repository" >&2
      exit 2
    fi
  fi
  for arg in "$@"; do
    case "$arg" in
      *quality-gate/rust*)   [ -n "${MOCK_DOCKER_RC_rust:-}" ]   && exit "$MOCK_DOCKER_RC_rust" ;;
      *quality-gate/go*)     [ -n "${MOCK_DOCKER_RC_go:-}" ]     && exit "$MOCK_DOCKER_RC_go" ;;
      *quality-gate/java*)   [ -n "${MOCK_DOCKER_RC_java:-}" ]   && exit "$MOCK_DOCKER_RC_java" ;;
      *quality-gate/nodejs*) [ -n "${MOCK_DOCKER_RC_nodejs:-}" ] && exit "$MOCK_DOCKER_RC_nodejs" ;;
    esac
  done
  if [ -n "${MOCK_DOCKER_RC:-}" ]; then
    exit "$MOCK_DOCKER_RC"
  fi
  exit 0
fi
exit 0
EOF
chmod +x "$SBX/bin/docker"
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

# 7. Monorepo with .qg.yaml (no root sentinel) -> gate is NOT skipped silently
rm -f "$SBX/Cargo.toml" "$SBX/go.mod" "$SBX/.qg-hook.json"
mkdir -p "$SBX/backend" "$SBX/mobile"
printf '<project></project>\n' > "$SBX/backend/pom.xml"
printf '{"name":"mobile"}\n' > "$SBX/mobile/package.json"
cat > "$SBX/.qg.yaml" <<'YAML'
projects:
  - path: backend
    language: java
  - path: mobile
    language: nodejs
YAML
run
if [ -z "$out" ]; then
  echo "FAIL: monorepo with .qg.yaml was skipped silently (out is empty)"
  fail=1
elif grep -q "docker unavailable" <<<"$out"; then
  echo "ok  : monorepo with .qg.yaml detects projects and engages gate"
else
  echo "FAIL: unexpected monorepo output: $out"
  fail=1
fi

# 8. Multi-language support: one opt-out + one regressing language denies PR
export MOCK_DOCKER_AVAILABLE=1
export MOCK_DOCKER_RC_java=0
export MOCK_DOCKER_RC_nodejs=1
cfg '{"pr_gate":{"java":false}}'
run
if disabled java "$out" && grep -q '"permissionDecision": *"deny"' <<<"$out"; then
  echo "ok  : multi-language respects opt-out for java and denies on nodejs regression"
else
  echo "FAIL: multi-language should deny PR when nodejs regresses (rc=$rc): $out"
  fail=1
fi

# 9. Git Worktree execution: mounts GIT_COMMON_DIR so docker doesn't fail with "not a git repository"
git -C "$SBX" commit --allow-empty -m "initial commit" >/dev/null 2>&1
WT_DIR="$SBX/worktree-test"
git -C "$SBX" worktree add -b wt-branch "$WT_DIR" >/dev/null 2>&1
export CLAUDE_PROJECT_DIR="$WT_DIR"
printf '[package]\nname="wt"\n' > "$WT_DIR/Cargo.toml"
rm -f "$WT_DIR/.qg-hook.json" "$WT_DIR/.qg.yaml"
EXPECTED_COMMON="$(git -C "$WT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git -C "$WT_DIR" rev-parse --git-common-dir 2>/dev/null)"
export MOCK_EXPECT_COMMON_DIR="$EXPECTED_COMMON"
export MOCK_DOCKER_AVAILABLE=1
export MOCK_DOCKER_RC=0
run
if grep -q '"permissionDecision": *"deny"' <<<"$out" && grep -q "not a git repository" <<<"$out"; then
  echo "FAIL: worktree execution failed because GIT_COMMON_DIR was not mounted: $out"
  fail=1
elif [ "$rc" = 0 ] && ! grep -q '"permissionDecision": *"deny"' <<<"$out"; then
  echo "ok  : git worktree mounts GIT_COMMON_DIR and succeeds"
else
  echo "FAIL: unexpected worktree output (rc=$rc): $out"
  fail=1
fi
unset MOCK_EXPECT_COMMON_DIR
unset MOCK_DOCKER_AVAILABLE
unset MOCK_DOCKER_RC
unset MOCK_DOCKER_RC_java
unset MOCK_DOCKER_RC_nodejs
export CLAUDE_PROJECT_DIR="$SBX"
git -C "$SBX" worktree remove --force "$WT_DIR" >/dev/null 2>&1

exit $fail
