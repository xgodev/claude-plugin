#!/usr/bin/env bash
# Responsibility: report an installed plugin whose cache drifted from the version it claims to be.
set -uo pipefail

# The cache is what actually loads. A source fix published WITHOUT a version
# bump never reaches it, so the stale copy keeps costing context forever --
# that is how a removed MCP server kept loading for weeks. Only the cache dir
# whose name matches the marketplace's current version is a real finding; an
# older pinned version is expected to differ. Only files that change what
# loads are compared; README and licence drift is noise.
loaded_paths='.mcp.json .claude-plugin skills hooks commands agents'

shopt -s nullglob
for market in "$HYGIENE_HOME"/plugins/marketplaces/*; do
  name="$(basename "$market")"
  for manifest in "$market"/.claude-plugin/plugin.json "$market"/*/.claude-plugin/plugin.json; do
    [ -f "$manifest" ] || continue
    source_dir="$(dirname "$(dirname "$manifest")")"
    plugin="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$manifest")"
    version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version",""))' "$manifest")"
    cached="$HYGIENE_HOME/plugins/cache/$name/$plugin/$version"
    [ -n "$plugin" ] && [ -n "$version" ] && [ -d "$cached" ] || continue

    for rel in $loaded_paths; do
      [ -e "$source_dir/$rel" ] || [ -e "$cached/$rel" ] || continue
      diff -rq --exclude=.git "$source_dir/$rel" "$cached/$rel" >/dev/null 2>&1 && continue
      finding "$name/$plugin $version: cached '$rel' differs from the source - bump the version so the cache refreshes"
      if [ "$HYGIENE_FIX" = "1" ]; then
        rm -rf "$cached/$rel" && cp -R "$source_dir/$rel" "$cached/$rel" \
          && printf '      refreshed %s\n' "$rel"
      fi
    done
  done
done
