# Changelog

## [0.6.0]

BREAKING -- marketplace rename + cross-marketplace dependencies.
Requires Claude Code v2.1.110+ (cross-marketplace deps support).

Note: 0.5.0 was pushed briefly with a decoupled shape (no dependencies)
and is superseded by this entry. Use 0.6.0+.

- Marketplace `name` renamed from `xgodev` to `xgodev-claude-plugin`
  (more specific identifier: a single owner can host multiple
  marketplaces; the generic `xgodev` ID collided with other `xgodev/*`
  marketplaces). Installed as `claude-plugin@xgodev-claude-plugin`.
- Dependencies migrated from the same-marketplace re-listing pattern
  to the canonical **cross-marketplace** form. `plugin.json`
  `dependencies` now uses the object shape
  `{ "name": "<plugin>", "marketplace": "xgodev-<plugin>" }` for
  `boost`, `quality-gate` and `dev-rules`, pointing at their standalone
  marketplaces (`xgodev-boost`, `xgodev-quality-gate`,
  `xgodev-dev-rules`). The previous re-listings of those three plugins
  under `plugins` in `marketplace.json` were removed (they would
  collide with the standalone marketplaces). Source of truth:
  https://code.claude.com/docs/en/plugin-dependencies
- `marketplace.json` declares
  `allowCrossMarketplaceDependenciesOn: ["xgodev-boost",
  "xgodev-quality-gate", "xgodev-dev-rules"]` so Claude Code is
  allowed to resolve and auto-install those dependencies on
  `claude-plugin` install.
- `CLAUDE.md`, `README.md` and `plugin.json` `description` synced with
  the umbrella + cross-marketplace shape in the same change.

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
