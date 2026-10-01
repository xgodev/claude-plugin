#!/usr/bin/env bash
# Responsibility: report agent memory directories that are too big to carry every session.
set -uo pipefail

# MEMORY.md is injected into EVERY session, so it is the expensive one.
index_limit="${HYGIENE_MEMORY_INDEX_BYTES:-4000}"
dir_limit="${HYGIENE_MEMORY_DIR_BYTES:-60000}"

shopt -s nullglob
for dir in "$HYGIENE_HOME"/projects/*/memory; do
  project="$(basename "$(dirname "$dir")")"
  total=0
  for f in "$dir"/*.md; do
    total=$((total + $(wc -c <"$f" | tr -d " ")))
  done
  index="$dir/MEMORY.md"
  if [ -f "$index" ]; then
    size="$(wc -c <"$index" | tr -d " ")"
    if [ "$size" -gt "$index_limit" ]; then
      finding "$project: MEMORY.md is ${size}B (limit ${index_limit}B) - it loads in every session"
    fi
  fi
  if [ "$total" -gt "$dir_limit" ]; then
    finding "$project: memory is ${total}B across $(ls "$dir"/*.md 2>/dev/null | wc -l | tr -d ' ') files (limit ${dir_limit}B)"
    du -k "$dir"/*.md 2>/dev/null | sort -rn | head -3 | while read -r kb path; do
      printf '      %sK  %s\n' "$kb" "$(basename "$path")"
    done
  fi
done
