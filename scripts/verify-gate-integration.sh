#!/usr/bin/env bash
# verify-gate-integration.sh -- prove the pinned quality-gate image runs
# correctly with the plugin's exact invocation.
#
# The plugin does not bundle the gate anymore; it runs
# `ghcr.io/xgodev/quality-gate/<lang>:<tag>`. This script makes "does that image
# actually work with how we call it" a CHECKED FACT, not an assumption. It
# fails LOUDLY (non-zero) when the pinned image is missing/unpullable or does
# not produce a verdict -- so the integration can never silently rot behind the
# skill/hook fail-open.
#
#   scripts/verify-gate-integration.sh [lang] [tag]
#   QG_IMAGE=my-local:tag scripts/verify-gate-integration.sh   # override image
#
# Defaults: lang=rust, tag=${QG_TAG:-latest}. Only rust has a self-contained
# fixture here; other languages are verified once their images publish.
set -uo pipefail

LANG_ARG="${1:-rust}"
TAG="${2:-${QG_TAG:-latest}}"
IMAGE="${QG_IMAGE:-ghcr.io/xgodev/quality-gate/${LANG_ARG}:${TAG}}"

fail() { echo "FAIL: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || fail "docker not installed"
docker info >/dev/null 2>&1 || fail "docker daemon not running"
command -v jq >/dev/null 2>&1 || fail "jq not installed"

echo "== 1. pinned image is published & pullable: $IMAGE =="
if ! docker manifest inspect "$IMAGE" >/dev/null 2>&1; then
  # Local-only images (QG_IMAGE override) have no registry manifest; accept if
  # present locally. Otherwise this is the real failure the user cares about.
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    fail "image '$IMAGE' is not pullable (not published, private, or wrong tag). See xgodev/quality-gate#15."
  fi
  echo "   (using local image $IMAGE)"
fi

[ "$LANG_ARG" = rust ] || { echo "SKIP: no self-contained fixture for '$LANG_ARG' yet"; exit 0; }

echo "== 2. build a throwaway rust repo =="
repo="$(mktemp -d)"; logs="$(mktemp -d)"
trap 'rm -rf "$repo" "$logs"' EXIT
mkdir -p "$repo/src"
cat > "$repo/Cargo.toml" <<'TOML'
[package]
name = "qgint"
version = "0.0.0"
edition = "2021"
TOML
cat > "$repo/src/lib.rs" <<'RS'
pub fn add(a: u32, b: u32) -> u32 {
    a + b
}

#[cfg(test)]
mod tests {
    #[test]
    fn adds() {
        assert_eq!(super::add(2, 2), 4);
    }
}
RS
git -C "$repo" -c init.defaultBranch=main init -q .
git -C "$repo" config user.email ci@qg && git -C "$repo" config user.name ci
git -C "$repo" add -A && git -C "$repo" commit -qm base
git -C "$repo" checkout -qb feature
cat >> "$repo/src/lib.rs" <<'RS'

pub fn mul(a: u32, b: u32) -> u32 {
    a * b
}
RS
git -C "$repo" add -A && git -C "$repo" commit -qm change

echo "== 3. run the plugin's exact invocation =="
plat="${QG_PLATFORM:+--platform $QG_PLATFORM}"
docker run --rm $plat -v "$repo:/src" -w /src -v "$logs:/logs" "$IMAGE" \
  --base main --format json --log-dir /logs \
  > "$logs/result.json" 2> "$logs/stderr.log"
rc=$?
echo "   exit=$rc"
if grep -qi 'no matching manifest' "$logs/stderr.log"; then
  fail "image '$IMAGE' has no variant for this host arch ($(uname -m)). Publish multi-arch (xgodev/quality-gate#16), or set QG_PLATFORM=linux/amd64 to run under emulation."
fi

echo "== 4. assert a real verdict was produced =="
case "$rc" in
  0|1) : ;;  # passed / regressed -- the gate RAN, which is what we verify
  2) fail "gate returned tool-error (exit 2): $(tail -n3 "$logs/stderr.log" | tr '\n' ' ')" ;;
  3) fail "gate did not detect rust (exit 3) -- image/dispatcher problem" ;;
  125|126|127) fail "docker could not run the image (exit $rc)" ;;
  *) fail "unexpected exit $rc: $(tail -n3 "$logs/stderr.log" | tr '\n' ' ')" ;;
esac

jq -e '.' "$logs/result.json" >/dev/null 2>&1 || fail "output is not valid JSON: $(head -c200 "$logs/result.json")"
lang="$(jq -r 'if has("results") then .results[0].language else .language end' "$logs/result.json")"
verdict="$(jq -r 'if has("aggregate_verdict") then .aggregate_verdict else .verdict end' "$logs/result.json")"
[ "$lang" = rust ] || fail "expected language=rust, got '$lang'"
[ -n "$verdict" ] && [ "$verdict" != null ] || fail "no verdict in output"

echo "PASS: $IMAGE ran the gate (language=$lang, verdict=$verdict, exit=$rc)"
