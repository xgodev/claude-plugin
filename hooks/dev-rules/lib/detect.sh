#!/usr/bin/env bash
# dev-rules: language-agnostic production-vs-test path detection.
# Sourced by the gate hooks. Reads optional .dev-rules.json at the project
# root ($CLAUDE_PROJECT_DIR); otherwise uses built-in defaults. Best-effort
# and tunable per-repo via .dev-rules.json (see README).

DR_DEFAULT_PROD_SEGMENTS="src lib app cmd internal pkg crates domain"

# dr_config <jq-filter> <default> -- read a key from .dev-rules.json if present.
dr_config() {
  local filter="$1" default="$2" cfg="${CLAUDE_PROJECT_DIR:-.}/.dev-rules.json"
  if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
    # NOTE: do NOT use `// empty` here -- jq's `//` treats a JSON `false`
    # as absent, which would break the `enabled:false` opt-out. Filter for
    # null on the shell side instead.
    local v; v="$(jq -r "$filter" "$cfg" 2>/dev/null)"
    [ -n "$v" ] && [ "$v" != "null" ] && { printf '%s' "$v"; return; }
  fi
  printf '%s' "$default"
}

# Kill switches, checked before anything else:
#   DEV_RULES_OFF=1        -> off for the whole session (set when launching:
#                             DEV_RULES_OFF=1 claude); dies with the process.
#   .dev-rules/.off        -> off until the file is removed; toggled any time
#                             (touch/rm) and NEVER cleared by clear-after-commit.
#   .dev-rules.json enabled:false -> off permanently for the project.
dr_enabled() {
  [ "${DEV_RULES_OFF:-}" = "1" ] && return 1
  [ -f "${CLAUDE_PROJECT_DIR:-.}/.dev-rules/.off" ] && return 1
  [ "$(dr_config '.enabled' 'true')" != "false" ]
}

# Translate `**` -> `*` (bash [[ ]] `*` already spans `/`). The replacement is a
# bare `*`, NOT `\*`: an escaped `\*` would match a literal asterisk, so globs
# like `crates/**/src/**` silently matched nothing (broke .dev-rules.json globs).
dr_glob_match() { local p="$1" g="${2//\*\*/*}"; [[ "$p" == $g ]]; }

dr_is_test_file() {
  case "$1" in
    *_test.*|*_tests.*|*.test.*|*.spec.*|*_spec.rb|*_tests.rs) return 0 ;;
    tests/*|test/*|__tests__/*|spec/*) return 0 ;;
    */tests/*|*/test/*|*/__tests__/*|*/spec/*|*conftest.py) return 0 ;;
  esac
  local g
  while IFS= read -r g; do
    [ -n "$g" ] && dr_glob_match "$1" "$g" && return 0
  done <<EOF
$(dr_config '.test_globs[]?' '')
EOF
  return 1
}

dr_is_docs_or_config() {
  case "$1" in
    *.md|*.markdown|*.json|*.yaml|*.yml|*.toml|*.txt|*.lock) return 0 ;;
    .github/*|docs/*|.dev-rules/*|*/.github/*|*/docs/*|*/.dev-rules/*) return 0 ;;
  esac
  return 1
}

# Issue #6: a directory that can CONTAIN files matching a production glob is
# production too -- otherwise directory-scoped reads (grep -r dir/, rg dir,
# ls dir) slip under file-shaped globs like crates/**/src/**. Walks the two
# segment lists; `**` in the glob means everything below may match.
dr_dir_may_contain() { # <dir> <glob>
  local dir="${1%/}" glob="$2"
  local IFS=/
  local -a ds gs
  read -ra ds <<<"$dir"; read -ra gs <<<"$glob"
  local i=0 n=${#ds[@]} m=${#gs[@]} g
  while [ "$i" -lt "$n" ]; do
    [ "$i" -ge "$m" ] && return 1
    g="${gs[$i]}"
    [ "$g" = '**' ] && return 0
    case "${ds[$i]}" in $g) ;; *) return 1 ;; esac
    i=$((i+1))
  done
  return 0
}

dr_is_production() {
  local path="$1"
  dr_is_test_file "$path" && return 1
  dr_is_docs_or_config "$path" && return 1
  # Explicit production_globs in config win exclusively when present.
  # A token counts as a directory when it ends in `/` or exists as a dir
  # (relative to the project or the cwd).
  local proj="${CLAUDE_PROJECT_DIR:-.}"
  local dirchk="${path%/}"
  dirchk="${dirchk#"$proj"/}"; dirchk="${dirchk#./}"
  local is_dir=1
  if [ "${path%/}" != "$path" ] || [ -d "$proj/$dirchk" ] || [ -d "$dirchk" ]; then
    is_dir=0
  fi
  local g had_cfg=1
  while IFS= read -r g; do
    if [ -n "$g" ]; then
      had_cfg=0
      dr_glob_match "$path" "$g" && return 0
      [ "$is_dir" = 0 ] && dr_dir_may_contain "$dirchk" "$g" && return 0
    fi
  done <<EOF
$(dr_config '.production_globs[]?' '')
EOF
  [ "$had_cfg" = 0 ] && return 1
  # Built-in default: a known production segment appears in the path.
  local seg
  for seg in $DR_DEFAULT_PROD_SEGMENTS; do
    case "$path" in "$seg"|"$seg"/*|*/"$seg"|*/"$seg"/*) return 0 ;; esac
  done
  return 1
}
