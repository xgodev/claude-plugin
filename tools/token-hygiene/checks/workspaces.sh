#!/usr/bin/env bash
# Responsibility: report isolated agent workspaces that are finished and only taking disk.
set -uo pipefail

# An agent workspace is a full clone, so a forgotten one costs gigabytes. It is
# only safe to drop when the tree is clean AND every commit is on the remote;
# anything else holds work that the remote cannot give back, so it is listed
# as keep and never touched. Deleting is left to a person either way.
dir_name="${HYGIENE_WORKSPACE_DIR:-.solvers}"

shopt -s nullglob
for root in ${HYGIENE_ROOTS//:/ }; do
  while IFS= read -r workspaces; do
    for ws in "$workspaces"/*; do
      [ -d "$ws/.git" ] || continue
      label="${ws#$root/}"
      dirty="$(git -C "$ws" status --porcelain 2>/dev/null)"
      branch="$(git -C "$ws" branch --show-current 2>/dev/null)"
      unpushed="$(git -C "$ws" log --oneline "@{upstream}..HEAD" 2>/dev/null || echo unknown)"
      size="$(du -sh "$ws" 2>/dev/null | cut -f1)"
      if [ -n "$dirty" ] || [ -n "$unpushed" ]; then
        finding "$label ($size, $branch): KEEP - uncommitted or unpushed work"
      else
        finding "$label ($size, $branch): done - clean and fully pushed, safe to delete once its issue is closed"
      fi
    done
  done < <(find "$root" -maxdepth 4 -type d -name "$dir_name" 2>/dev/null)
done
