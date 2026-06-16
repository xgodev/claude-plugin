# CLAUDE.md -- claude-plugin

This repo is **`claude-plugin`**: an umbrella Claude Code plugin by
`xgodev`. It **bundles no skills of its own** and provides capabilities
through **cross-marketplace plugin dependencies**: `golang-boost@xgodev-boost`,
`quality-gate@xgodev-quality-gate`, `dev-rules@xgodev-dev-rules`,
`skill-rules@xgodev-skill-rules`. It also wires one MCP server
(`playwright`). Installing `claude-plugin` should auto-install the four
dependencies (subject to user trust of those
marketplaces via this marketplace's `allowCrossMarketplaceDependenciesOn`
allowlist).

These are hard rules. Read them before changing anything so a future
session does not repeat past mistakes.

## Hard rules

- **Docs are ALWAYS updated in the same change. No exceptions.** Any
  change to structure, dependencies, MCP, or version updates -- in the
  **same commit** -- `README.md`, `CHANGELOG.md`, this `CLAUDE.md`, and
  the `.claude-plugin/plugin.json` `description` if it no longer matches
  reality. A manifest or doc that lies about the project is a defect,
  not a follow-up. Before committing: "what doc does this change make
  false?" -- fix it now.
- **3-file version discipline.** A version change moves together, same
  commit: `.claude-plugin/plugin.json` `version`, the README `- Version:`
  line (if present), and a `CHANGELOG.md` entry. Verify they match
  before committing.
- **English only. Everywhere.** README, CHANGELOG, CLAUDE.md, manifests,
  descriptions. Public OSS -- no Portuguese anywhere.
- **Zero proprietary / internal references.** No `carrefour`,
  `bitbucket`, internal names/URLs. Before push:
  `grep -ri -E 'carrefour|bitbucket' . --include='*' | grep -v '\.git/'`
  must be empty.
- **This plugin bundles NO skill.** Skills (if ever added) live in
  `skills/<name>/SKILL.md` at the plugin root (NOT `.claude/skills/`,
  which is project-local, not plugin-distributed). The
  `quality-gate` / `dev-rules` / `golang-boost` skills come from their
  respective dependency plugins -- never copy them back in here.
- **Cross-marketplace dependency pattern (canonical, per official
  docs).** Each dependency on a non-bundled `xgodev` plugin uses the
  object form in `plugin.json`:
  `{ "name": "<plugin>", "marketplace": "xgodev-<plugin>" }`. Do NOT use
  bare strings (those would resolve in this marketplace and force a
  re-listing). Do NOT re-list those plugins under `plugins` in
  `marketplace.json` -- the standalone `xgodev-<plugin>` marketplaces
  are canonical. The umbrella's `marketplace.json` must declare each
  target marketplace in `allowCrossMarketplaceDependenciesOn`,
  otherwise auto-install of the dep is blocked with a
  `cross-marketplace` error. Source of truth:
  https://code.claude.com/docs/en/plugin-dependencies
- **MCP servers** are declared in `.claude-plugin/plugin.json`
  `mcpServers` (e.g. `playwright` = stdio `npx -y @playwright/mcp@latest`).
- **ASCII** identifiers/commands; no accents, no em-dash (use `--`).
  Templates (if any) use `{{UPPER_SNAKE}}` placeholders only.
- **Never guess Claude Code plugin specifics.** Verify against
  https://code.claude.com/docs (plugins/skills/plugin-dependencies)
  before asserting.
- **Minimum Claude Code version.** Cross-marketplace dependencies
  require Claude Code v2.1.110+. If support for older versions is ever
  needed, switch to the legacy "same-marketplace re-listing" pattern
  (bare names in `dependencies` + re-listings in `marketplace.json`)
  and accept the ID collisions that come with it.

## Common mistakes

- Using bare strings in `dependencies` (e.g. `"boost"`) combined with
  re-listings in `marketplace.json` -- that was the 0.4.0 pattern; it
  collides with the standalone `xgodev-<plugin>` marketplaces. Use the
  cross-marketplace object form.
- Forgetting to add a target marketplace to
  `allowCrossMarketplaceDependenciesOn` -- the dependency stops
  auto-installing and surfaces a `cross-marketplace` error.
- Bumping `plugin.json` and forgetting README/CHANGELOG (or leaving the
  `description` describing an old shape).
- Putting skills in `.claude/skills/` for a distributed plugin (wrong;
  use `skills/` at the plugin root).
- Any Portuguese string (run a language sweep before push).
