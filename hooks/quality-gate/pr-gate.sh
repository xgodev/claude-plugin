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

# --- detect supported languages (root sentinels, subdirs, .qg.yaml) -------
detect_dir_langs() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  [ -f "$dir/Cargo.toml" ] && echo "rust"
  [ -f "$dir/go.mod" ] && echo "go"
  [ -f "$dir/pom.xml" ] && echo "java"
  { [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ]; } && echo "kotlin"
  [ -f "$dir/Package.swift" ] && echo "swift"
  { [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/requirements.txt" ]; } && echo "python"
  [ -f "$dir/package.json" ] && echo "nodejs"
  if [ ! -f "$dir/package.json" ]; then
    if ls "$dir"/*.html "$dir"/*.css >/dev/null 2>&1; then
      echo "web"
    fi
  fi
}

parse_qg_yaml() {
  local yaml="$1"
  local base_dir="$2"
  [ -f "$yaml" ] || return 0

  local in_projects=0
  local cur_path=""
  local cur_lang=""

  local rx_non_indent="^[^[:space:]#]"
  local rx_item="^[[:space:]]*-[[:space:]]*(.*)"
  local rx_path="path:[[:space:]]*[\"'\'']?([^\"'\''[:space:],}#]+)"
  local rx_lang="(lang|language):[[:space:]]*[\"'\'']?([^\"'\''[:space:],}#]+)"
  local rx_simple="^[\"'\'']?([^\"'\''[:space:]#:]+)[\"'\'']?$"

  flush_item() {
    if [ -n "$cur_lang" ]; then
      echo "$cur_lang"
    elif [ -n "$cur_path" ]; then
      detect_dir_langs "$base_dir/$cur_path"
    fi
    cur_path=""
    cur_lang=""
  }

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_projects" -eq 1 ]; then
      if [[ "$line" =~ $rx_non_indent ]]; then
        flush_item
        in_projects=0
      fi
    fi

    if [ "$in_projects" -eq 1 ]; then
      if [[ "$line" =~ $rx_item ]]; then
        flush_item
        local rest="${BASH_REMATCH[1]}"
        if [[ "$rest" =~ $rx_path ]]; then
          cur_path="${BASH_REMATCH[1]}"
        fi
        if [[ "$rest" =~ $rx_lang ]]; then
          cur_lang="${BASH_REMATCH[2]}"
        fi
        if [ -z "$cur_path" ] && [ -z "$cur_lang" ] && [[ "$rest" =~ $rx_simple ]]; then
          cur_path="${BASH_REMATCH[1]}"
        fi
      else
        if [[ "$line" =~ $rx_path ]]; then
          cur_path="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ $rx_lang ]]; then
          cur_lang="${BASH_REMATCH[2]}"
        fi
      fi
    fi

    if [[ "$line" =~ ^projects: ]]; then
      in_projects=1
    fi
  done < "$yaml"

  if [ "$in_projects" -eq 1 ]; then
    flush_item
  fi
}

raw_langs=""
if [ -f "$root/.qg.yaml" ]; then
  raw_langs="$(parse_qg_yaml "$root/.qg.yaml" "$root")"
fi
if [ -z "$raw_langs" ]; then
  raw_langs="$(detect_dir_langs "$root")"
  for sub in "$root"/*; do
    [ -d "$sub" ] || continue
    raw_langs="${raw_langs}"$'\n'"$(detect_dir_langs "$sub")"
  done
fi

detected_langs=()
for l in $raw_langs; do
  case "$l" in
    rust|go|java|kotlin|swift|python|nodejs|web)
      already=0
      for u in "${detected_langs[@]:-}"; do
        [ "$u" = "$l" ] && already=1 && break
      done
      [ "$already" -eq 0 ] && detected_langs+=("$l")
      ;;
  esac
done

[ "${#detected_langs[@]}" -eq 0 ] && exit 0   # no supported language -> allow

# --- per-project opt-out (.qg-hook.json) ----------------------------------
# A repo can turn the PR-gate hook OFF for a given language via a versioned
# `.qg-hook.json` at its root. This is NOT a bypass (no QG_BYPASS_REASON, no
# audit log): it declares that this language's gate lives in CI only. Shapes:
#   {"pr_gate": false}            -> off for every language
#   {"pr_gate": {"rust": false}}  -> off for rust only
# Anything else (file absent, invalid JSON, key/lang absent, value not false)
# leaves the gate ON -- fail-safe toward enforcement.
cfg="$root/.qg-hook.json"
active_langs=()
for lang in "${detected_langs[@]}"; do
  if [ -f "$cfg" ]; then
    flag="$(jq -r --arg l "$lang" '
      .pr_gate as $g
      | if $g == false then "off"
        elif ($g | type) == "object" and $g[$l] == false then "off"
        else "on" end' "$cfg" 2>/dev/null || echo on)"
    if [ "$flag" = "off" ]; then
      echo "qg-hook: PR-gate disabled for '$lang' via .qg-hook.json; skipping" >&2
      continue
    fi
  fi
  active_langs+=("$lang")
done

[ "${#active_langs[@]}" -eq 0 ] && exit 0

# The gate is a Docker image (xgodev/quality-gate). Docker absent -> fail open:
# a missing runtime must never brick the user's git.
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "qg-hook: docker unavailable; skipping gate enforcement" >&2
  exit 0
fi

# --- resolve git worktree common dir --------------------------------------
# In a git worktree, $root/.git is a file pointing to <repo>/.git/worktrees/<name>.
# Mount GIT_COMMON_DIR into the container so git operations succeed inside /src.
common_dir="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git -C "$root" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$common_dir" ] && [ "${common_dir:0:1}" != "/" ]; then
  common_dir="$(cd "$root" && cd "$common_dir" 2>/dev/null && pwd || true)"
fi

worktree_vol=()
if [ -n "$common_dir" ] && [ -d "$common_dir" ]; then
  case "$common_dir" in
    "$root"|"$root"/*) ;;
    *) worktree_vol=(-v "$common_dir:$common_dir") ;;
  esac
fi

# --- resolve base ref (upstream -> origin default -> absolute) ------------
base="$(git -C "$proj" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [ -z "$base" ]; then
  base="$(git -C "$proj" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
fi

# --- run the gate in the container for all active languages ---------------
pull="${QG_PULL:-always}"
plat="${QG_PLATFORM:+--platform $QG_PLATFORM}"

run_gate() {
  docker run --rm "--pull=$pull" $plat ${worktree_vol[@]+"${worktree_vol[@]}"} -v "$root:/src" -w /src -v "$logs:/logs" "$image" --log-dir /logs "$@" 2>&1
}

for lang in "${active_langs[@]}"; do
  image="${QG_IMAGE:-ghcr.io/xgodev/quality-gate/${lang}:${QG_TAG:-latest}}"
  logs="$(mktemp -d "${TMPDIR:-/tmp}/qg-hook-XXXXXX")"

  if [ -n "$base" ]; then
    out="$(run_gate --base "$base")"; rc=$?
  else
    out="$(run_gate)"; rc=$?   # absolute mode
  fi
  rm -rf "$logs"

  # Image not pulled / pull denied / daemon hiccup -> docker exit 125/126/127.
  # Fail open: enforcement is best-effort locally, CI is the hard gate.
  case "$rc" in
    125|126|127)
      echo "qg-hook: image '$image' unavailable (docker rc $rc); skipping" >&2
      continue
      ;;
    0|3)
      continue
      ;;
  esac

  # --- map exit code to decision ------------------------------------------
  verdict="regressed/failed"
  [ "$rc" -eq 2 ] && verdict="tool error"
  tail_out="$(printf '%s' "$out" | tail -n 6 | tr '\n' ' ')"
  if [ "${#active_langs[@]}" -eq 1 ] && [ "${#detected_langs[@]}" -eq 1 ]; then
    reason="Quality gate ${verdict} (qg exit ${rc}). ${tail_out} -- run the gate and fix, or set QG_BYPASS_REASON to override."
  else
    reason="Quality gate ${verdict} for '${lang}' (qg exit ${rc}). ${tail_out} -- run the gate and fix, or set QG_BYPASS_REASON to override."
  fi

  jq -n --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
done

exit 0
