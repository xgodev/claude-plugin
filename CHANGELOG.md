# Changelog

## [1.1.9]

### Fixed

- A `.dev-rules/.mode-feature` sentinel was accidentally committed,
  which would disable the RED-first gate for every clone of this repo.
  Removed from the index; `.dev-rules/` is now gitignored (sentinels are
  per-machine runtime state, never repo content).

## [1.1.8]

### Fixed

- `red-first-guard.sh` never matched project-relative `production_globs`
  against the absolute paths Claude Code sends for Edit/Write, so a
  `.dev-rules.json` with explicit globs silently disabled the gate. The
  guard now strips the project prefix (and an isolated-workspace
  `.solvers/<name>/` prefix) before classifying the path.

## [1.1.7]

### Fixed

- The pre-push sweep instruction in CLAUDE.md embedded the very names it
  exists to keep out of a public repo; the rule is now stated
  generically (the concrete pattern lives outside the repo).

## [1.1.6]

### Changed

- README context-overhead numbers refreshed for the trimmed
  descriptions: plugin overhead is now ~370 tokens/session (+1.4%).
  Measured end-to-end, the 1.1.5 + ux-ui-mastery 3.0.1 trims cut 752
  tokens/session off a fully loaded setup (29,227 -> 28,475).

## [1.1.5]

### Changed

- **Skill descriptions trimmed to trigger-only lines** (`boost`,
  `quality-gate`) -- descriptions load into every session's context;
  workflow and prohibition text lives in the SKILL.md bodies (where it
  already was). Same routing triggers, fewer always-on tokens. The
  `ux-ui-mastery` fork got the same treatment for its 19 skills (3.0.1).

## [1.1.4]

### Added

- **Dependency on `ux-ui-mastery`** (Design Tribe Republic). Upstream
  `phazurlabs/ux-ui-mastery` ships a `plugin.json` that Claude Code
  rejects (`skills` entries point at `SKILL.md` files instead of skill
  directories, and custom paths lack the `./` prefix), which blocked the
  1.1.0 attempt. It is now served from the `xgodev/ux-ui-mastery` fork
  carrying exactly that manifest fix, listed in the `xgodev` marketplace
  with a GitHub source, and declared in `plugin.json` `dependencies` --
  auto-installs with `claude-plugin`. Switch the source back to upstream
  once the fix lands there.

## [1.1.3]

### Fixed

- **`superpowers` dependency resolves from `claude-plugins-official`.**
  Serving it from the `xgodev` marketplace (1.1.1) created a DUPLICATE
  plugin for everyone who already had
  `superpowers@claude-plugins-official` installed -- Claude Code treats
  the same plugin from two marketplaces as two plugins. The dependency
  is now the cross-marketplace form
  (`{"name": "superpowers", "marketplace": "claude-plugins-official"}`,
  allowlisted via `allowCrossMarketplaceDependenciesOn`); the official
  marketplace is preconfigured in Claude Code, so it still auto-installs
  with no extra step, and an existing install satisfies it.

## [1.1.2]

### Changed

- README describes current state only -- dropped a leftover historical
  aside in the context-overhead table. History lives here in the
  CHANGELOG, not in the README.

## [1.1.1]

### Added

- **Dependency on `superpowers`** (Jesse Vincent, `obra/superpowers`):
  core skills library (TDD, debugging, collaboration patterns). Listed in
  the `xgodev` marketplace with a GitHub source and declared in
  `plugin.json` `dependencies`, so it resolves same-marketplace and
  auto-installs with `claude-plugin` -- no extra
  `/plugin marketplace add`. Verified end-to-end with a local install.

### Removed

- **`ux-ui-mastery` dependency (added in 1.1.0) dropped for now.** Its
  upstream `plugin.json` (v3.0.0) is rejected by current Claude Code
  manifest validation (`commands` / `skills` fields), which made the
  whole `claude-plugin` install fail. Re-add once
  `phazurlabs/ux-ui-mastery` ships a valid manifest.

- **"Migrating from earlier layouts" README section.** The pre-1.0
  layouts (per-repo marketplaces, multi-plugin marketplace) had no real
  adoption, so the migration walkthrough was dead weight. The
  `renames` map in `marketplace.json` stays -- it still auto-migrates any
  old install transparently.

## [1.1.0]

### Changed

- **Marketplace name is `xgodev`.** Installs are `claude-plugin@xgodev`.
  The `xgodev-plugins` name introduced in 0.8.0 was never adopted in the
  wild, so no migration is needed; README install/update/auto-update
  instructions were updated.

- **Quality Gate bundle relocated to `tools/quality-gate/`.** The
  dispatcher `qg`, the eight per-language gate dirs (`go/`, `java/`,
  `kotlin/`, `nodejs/`, `python/`, `rust/`, `swift/`, `web/`) and the bats
  suite (`tests/`) moved from the repo root into
  `tools/quality-gate/`, leaving the root with only the plugin
  skeleton (`.claude-plugin/`, `skills/`, `hooks/`, `docs/`, `scripts/`).
  No gate behavior changed. All path references were updated in the same
  change: the pre-push hook, the `quality-gate` and
  `add-quality-gate` skills (`QG_PATH` still points at the quality-gate
  dir; its default is now `$CLAUDE_PLUGIN_ROOT/tools/quality-gate`),
  the test helpers, `docs/**`, per-language READMEs, `README.md`,
  `CONTRIBUTING.md`, and `CLAUDE.md`. CLI users: the dispatcher is now
  `<clone>/tools/quality-gate/qg`.

- **Hook scripts grouped by area.** The registry stays at
  `hooks/hooks.json` (standard auto-discovered path -- unchanged), but the
  scripts moved into per-area subdirectories:
  `hooks/quality-gate/pre-push-gate.sh` and
  `hooks/dev-rules/{red-first-guard.sh, clear-after-commit.sh, lib/}`.
  `hooks/test/` still covers all of them.
- **`add-quality-gate` is no longer shipped with the plugin.** It is a
  maintainer tool (adding a language to the gate is this repo's task, not
  something done in a consumer project), so it moved from `skills/` to
  the project-local `.claude/skills/add-quality-gate/`. End-user installs
  now receive four skills: `boost`, `quality-gate`, `dev-rules`,
  `skill-rules`. The `quality-gate` skill still names it on exit 3 -- the
  guidance ("open an issue / add the language in the gate repo") is
  unchanged.

### Added

- **Dependency on `ux-ui-mastery`** (Design Tribe Republic,
  `phazurlabs/ux-ui-mastery`). Declared in `plugin.json`
  `dependencies` with `marketplace: "ux-ui-mastery-marketplace"`;
  `marketplace.json` allowlists it via
  `allowCrossMarketplaceDependenciesOn`. Users add that marketplace
  first (`/plugin marketplace add phazurlabs/ux-ui-mastery`) and Claude
  Code auto-installs the dependency with `claude-plugin`.
- **"Context-window overhead" section in the README** with measured
  numbers: installing the plugin costs ~510 tokens per session (+1.9% over
  the Claude Code baseline), A/B-tested with `claude -p` on Claude Code
  2.1.199. Skill bodies, hooks, and the gate itself cost zero until used.

### Removed

- **`playwright` MCP server unbundled.** The plugin ships only xgodev's
  own capabilities; a third-party MCP server is not one of them. The
  `mcpServers` block was removed from `plugin.json`. If you used
  playwright through this plugin, add it to your own Claude Code config:
  `claude mcp add playwright -- npx -y @playwright/mcp@latest`.

### Fixed

- `docs/consume.md` and the per-language READMEs still instructed cloning
  the retired `xgodev/quality-gate` repo into a `~/.quality-gate` cache;
  they now point at this repo and the bundled gate path. A stale
  `~/.quality-gate` reinstall hint in the nodejs gate's tsconfig error
  message was updated too.

## [1.0.0]

### Changed

- **BREAKING: all-in-one plugin.** The four separate plugins were merged
  INTO `claude-plugin` itself: the `boost` skill set (from
  `xgodev/boost-claude`), the Quality Gate -- dispatcher `qg`, per-language
  gates, `quality-gate`/`add-quality-gate` skills, bats suite, opt-in
  pre-push hook (from `xgodev/quality-gate`) -- the `dev-rules` skill +
  RED-first enforcement hooks (from `xgodev/dev-rules`), and the
  `skill-rules` skill (from `xgodev/skill-rules`). One plugin, one version,
  one install; `dependencies` removed; `hooks/hooks.json` is the merge of
  the QG pre-push hook and the dev-rules hooks. Skills are now namespaced
  `claude-plugin:<skill>` (was `<plugin>:<skill>`). The marketplace lists
  only `claude-plugin` and maps the former plugin names to it via
  `renames` (auto-migration on Claude Code v2.1.193+; older versions:
  uninstall the four, install `claude-plugin`). Per-area user docs moved
  to `docs/golang-boost.md`, `docs/quality-gate.md`, `docs/dev-rules.md`,
  `docs/skill-rules.md`; the Quality Gate contract docs keep their
  `docs/` paths (`contract.md`, `languages/*`, `hooks.md`, ...). The
  source repos are retired (their pre-merge history stays there). Also
  ships the repo-level `LICENSE` (MIT) and a consolidated `CLAUDE.md`.

## [0.8.0]

### Changed

- **BREAKING (install path): single marketplace `xgodev-plugins`.** This
  repo's marketplace was renamed from `xgodev-claude-plugin` to
  `xgodev-plugins` and now lists every `xgodev` plugin directly:
  `golang-boost`, `quality-gate`, `dev-rules` and `skill-rules` via GitHub
  sources (`{ "source": "github", "repo": "xgodev/<repo>" }`, each shipped
  from its own repo), plus the umbrella `claude-plugin` (source `./`). The
  per-repo marketplaces (`xgodev-boost`, `xgodev-quality-gate`,
  `xgodev-dev-rules`, `xgodev-skill-rules`) are retired. `plugin.json`
  `dependencies` switched from the cross-marketplace object form to bare
  names (same-marketplace resolution), and
  `allowCrossMarketplaceDependenciesOn` was removed. Existing users must
  remove the old marketplaces and re-add this one -- see "Migrating from
  the per-repo marketplaces" in the README. README and CLAUDE.md rewritten
  for the new shape.

## [0.7.2]

### Changed

- **`golang-boost` moved to its own repo `xgodev/boost-claude`.** The
  `xgodev-boost` marketplace is now published from `xgodev/boost-claude`
  instead of `xgodev/boost` (the plugin was extracted so installing it no
  longer clones the whole framework). No JSON change was needed here: the
  cross-marketplace dependency resolves by marketplace name (`xgodev-boost`),
  which is unchanged. README links repointed to `xgodev/boost-claude`.

## [0.7.1]

### Fixed

- **`boost` dependency name corrected to `golang-boost`.** The `boost`
  dependency pointed at plugin name `boost`, but the plugin published in the
  `xgodev-boost` marketplace (repo `xgodev/boost`) is named `golang-boost`.
  Installing the umbrella therefore failed with
  `Dependency "boost@xgodev-boost" is not installed`. `plugin.json`
  `dependencies` now uses `{ "name": "golang-boost", "marketplace": "xgodev-boost" }`;
  README, `marketplace.json` description, and `CLAUDE.md` updated to match.

## [0.7.0]

### Added

- **`skill-rules` dependency.** Pulls `skill-rules@xgodev-skill-rules` via a
  cross-marketplace dependency, alongside `boost`, `quality-gate` and
  `dev-rules`. `skill-rules` is the skill-authoring companion to `dev-rules`:
  it requires every Claude skill to be portable across all developers and
  machines (no environment-tied hardcoding). `plugin.json` `dependencies`
  gains `{ "name": "skill-rules", "marketplace": "xgodev-skill-rules" }`, and
  `marketplace.json` `allowCrossMarketplaceDependenciesOn` gains
  `xgodev-skill-rules` so the dependency auto-installs.

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
