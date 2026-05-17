# Changelog

## [0.3.1]

- Added `CLAUDE.md` codifying the repo's hard rules (docs always synced,
  3-file version discipline, English-only, zero internal refs, dependency
  pattern, plugin skills location, MCP wiring).
- Fixed the `plugin.json` `description`: it still described a bundled
  quality-gate skill; this is an umbrella plugin that bundles no skills and
  provides them via dependencies.
- Translated `CHANGELOG.md` to English (public OSS — English only).

## [0.3.0]

- `quality-gate` skill unbundled; now provided via a dependency on the
  `quality-gate` plugin (re-listed from github.com/xgodev/quality-gate in
  `marketplace.json` + declared in `dependencies` in `plugin.json`). The
  skill and the gate ship inside that depended plugin.
- `boost` dependency and the `playwright` MCP server kept.

## [0.2.0]

- `boost` plugin dependency (re-listed from github.com/xgodev/boost in
  `marketplace.json` + declared in `dependencies` in `plugin.json`).
- `playwright` MCP server (`@playwright/mcp`, stdio via npx) wired in
  `mcpServers`.

## [0.1.0]

- First public release.
