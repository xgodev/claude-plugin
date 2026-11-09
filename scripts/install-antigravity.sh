#!/usr/bin/env bash
# install-antigravity.sh -- link this clone into Google Antigravity.
#
# Global (default): ~/.gemini/config/plugins/claude-plugin
# Project only: --project <dir> writes <dir>/.agents/plugins/claude-plugin
# instead and never touches the global configuration.
#
# The repository stays the single source of truth: Antigravity discovers
# the plugin manifest, hooks.json, and skills directly from this clone.
# Running `git pull` updates both Claude Code and Antigravity together.
#
# Usage:
#   ./scripts/install-antigravity.sh [--force]
#   ./scripts/install-antigravity.sh --project <dir> [--force]
#   ./scripts/install-antigravity.sh [--project <dir>] --uninstall
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT_DIR=""
PROJECT_SET=0
FORCE=0
UNINSTALL=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-antigravity.sh [--force]
  ./scripts/install-antigravity.sh --project <dir> [--force]
  ./scripts/install-antigravity.sh [--project <dir>] --uninstall

Without --project, the plugin is linked globally into
~/.gemini/config/plugins/claude-plugin.

With --project <dir>, the plugin is linked into
<dir>/.agents/plugins/claude-plugin and global config is left untouched.

Flags:
  --force      Replace an existing target that is not a symlink to this clone
  --uninstall  Remove the plugin symlink installed by this script
  -h, --help   Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --project=*)
      PROJECT_SET=1
      PROJECT_DIR="${1#--project=}"
      shift
      ;;
    --project)
      [ "$#" -ge 2 ] || { echo "install-antigravity: --project requires a directory argument" >&2; usage >&2; exit 2; }
      PROJECT_SET=1
      PROJECT_DIR="$2"
      shift 2
      ;;
    *)
      echo "install-antigravity: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$PROJECT_SET" -eq 1 ] && [ "$PROJECT_DIR" = "" ]; then
  echo "install-antigravity: --project requires a non-empty directory argument" >&2
  exit 2
fi

if [ "$PROJECT_DIR" != "" ]; then
  [ -d "$PROJECT_DIR" ] || { echo "install-antigravity: project directory not found: $PROJECT_DIR" >&2; exit 1; }
  PROJECT_ROOT="$(cd "$PROJECT_DIR" && pwd -P)"
  TARGET_PARENT="$PROJECT_ROOT/.agents/plugins"
  SCOPE="project $PROJECT_ROOT"
else
  TARGET_PARENT="${HOME}/.gemini/config/plugins"
  SCOPE="global ($TARGET_PARENT)"
fi

PLUGIN_LINK="$TARGET_PARENT/claude-plugin"

is_our_link() {
  local link="$1"
  local target="$2"
  [ -L "$link" ] || return 1
  [ "$(readlink "$link")" = "$target" ]
}

if [ "$UNINSTALL" -eq 1 ]; then
  if is_our_link "$PLUGIN_LINK" "$REPO_ROOT"; then
    rm -f "$PLUGIN_LINK"
    echo "Removed $PLUGIN_LINK"
    echo "claude-plugin uninstalled from $SCOPE."
  elif [ -e "$PLUGIN_LINK" ] || [ -L "$PLUGIN_LINK" ]; then
    echo "install-antigravity: $PLUGIN_LINK is not a symlink to $REPO_ROOT; left intact" >&2
    exit 1
  else
    echo "claude-plugin was not installed at $PLUGIN_LINK"
  fi
  exit 0
fi

[ -f "$REPO_ROOT/hooks.json" ] || { echo "install-antigravity: missing $REPO_ROOT/hooks.json" >&2; exit 1; }
[ -f "$REPO_ROOT/.antigravity-plugin/plugin.json" ] || { echo "install-antigravity: missing $REPO_ROOT/.antigravity-plugin/plugin.json" >&2; exit 1; }

mkdir -p "$TARGET_PARENT"

if is_our_link "$PLUGIN_LINK" "$REPO_ROOT"; then
  echo "already linked: $PLUGIN_LINK -> $REPO_ROOT"
else
  if [ -e "$PLUGIN_LINK" ] || [ -L "$PLUGIN_LINK" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "install-antigravity: refusing to replace $PLUGIN_LINK (use --force): not a symlink to $REPO_ROOT" >&2
      exit 1
    fi
    rm -rf "$PLUGIN_LINK"
  fi
  ln -s "$REPO_ROOT" "$PLUGIN_LINK"
  echo "linked: $PLUGIN_LINK -> $REPO_ROOT"
fi

echo
echo "claude-plugin installed successfully for $SCOPE."
echo "Location: $PLUGIN_LINK"
echo
if [ "$PROJECT_DIR" != "" ]; then
  echo "To use in your project, open $PROJECT_ROOT in Antigravity."
else
  echo "Restart Antigravity or Antigravity CLI (agy) to discover the new plugin directory."
fi
echo "Update anytime with: git -C \"$REPO_ROOT\" pull"
