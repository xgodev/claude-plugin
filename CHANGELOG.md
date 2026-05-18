# Changelog

## [0.4.0]

- Added `dev-rules` as a plugin dependency: declared in `plugin.json`
  `dependencies` and re-listed in `marketplace.json` (anonymous HTTPS clone
  of [`xgodev/dev-rules`](https://github.com/xgodev/dev-rules)). The umbrella
  now provides the macro language-agnostic engineering-discipline skill
  alongside `quality-gate` and `boost`. README + the stale `marketplace.json`
  self-description synced in the same change.

## [0.3.3]

- Removed the `## Skills` section from `README.md`: this plugin ships no
  skills of its own (umbrella). What capabilities you get is fully covered
  by the `## Dependencies` section; a Skills table listing `quality-gate`
  was misleading.

## [0.3.2]

- Synced `README.md` (it was not updated in the same change as 0.3.1 —
  the docs-always-synced rule was added then immediately violated): intro
  now matches the umbrella framing (bundles no skills; capabilities via
  dependencies); removed a Portuguese trigger example (`rodar QG`) —
  public OSS is English only.

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
