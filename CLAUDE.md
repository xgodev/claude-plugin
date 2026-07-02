# CLAUDE.md -- claude-plugin

This repo is two things at once:

1. **The single `xgodev` marketplace, `xgodev-plugins`**
   (`.claude-plugin/marketplace.json`): it lists every `xgodev` plugin
   -- `golang-boost`, `quality-gate`, `dev-rules`, `skill-rules` -- each
   with a GitHub source pointing at its own repository, plus the
   umbrella plugin below (source `./`). The plugin repos themselves are
   NOT marketplaces.
2. **The umbrella plugin `claude-plugin`**
   (`.claude-plugin/plugin.json`): it **bundles no skills of its own**;
   it declares the four plugins above as same-marketplace dependencies
   (bare names) and wires one MCP server (`playwright`). Installing
   `claude-plugin` auto-installs the four dependencies.

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
  `quality-gate` / `dev-rules` / `golang-boost` / `skill-rules` skills
  come from their respective dependency plugins -- never copy them back
  in here.
- **Single-marketplace pattern (canonical, per official docs).** The
  marketplace name is `xgodev-plugins` and it is the ONLY `xgodev`
  marketplace. Every `xgodev` plugin is listed under `plugins` in this
  repo's `marketplace.json`: external plugins use the GitHub source
  object `{ "source": "github", "repo": "xgodev/<repo>" }`; the umbrella
  uses `"./"`. Dependencies in `plugin.json` use bare names (they
  resolve within this same marketplace). Do NOT reintroduce
  cross-marketplace object deps (`{ "name", "marketplace" }`) or
  `allowCrossMarketplaceDependenciesOn` -- the per-repo marketplaces
  (`xgodev-boost`, `xgodev-quality-gate`, `xgodev-dev-rules`,
  `xgodev-skill-rules`, and this repo's former `xgodev-claude-plugin`)
  were retired in 0.8.0. Adding a new `xgodev` plugin = one new entry in
  `marketplace.json` (GitHub source) + one bare name in `plugin.json`
  `dependencies` if the umbrella should pull it. Source of truth:
  https://code.claude.com/docs/en/plugin-marketplaces and
  https://code.claude.com/docs/en/plugin-dependencies
- **A plugin's version lives in its own repo.** Each listed plugin's
  update cadence is driven by the `version` in that repo's
  `plugin.json`. Do not pin `version` on the external entries in this
  `marketplace.json` -- pinning here would freeze users until this repo
  is edited.
- **MCP servers** are declared in `.claude-plugin/plugin.json`
  `mcpServers` (e.g. `playwright` = stdio `npx -y @playwright/mcp@latest`).
- **ASCII** identifiers/commands; no accents, no em-dash (use `--`).
  Templates (if any) use `{{UPPER_SNAKE}}` placeholders only.
- **Never guess Claude Code plugin specifics.** Verify against
  https://code.claude.com/docs (plugins/skills/plugin-marketplaces/
  plugin-dependencies) before asserting.
- **Marketplace name is contract.** `xgodev-plugins` (and the plugin
  name `claude-plugin`) do not change without a documented migration in
  README + CHANGELOG -- a rename silently breaks every existing install
  (`/plugin install <name>@xgodev-plugins` and
  `extraKnownMarketplaces` entries).

## Common mistakes

- Reintroducing the cross-marketplace pattern (object deps +
  `allowCrossMarketplaceDependenciesOn`) -- that was the pre-0.8.0
  shape; it required every user to trust five marketplaces. The single
  `xgodev-plugins` marketplace replaced it.
- Pinning `version` on a GitHub-sourced plugin entry in
  `marketplace.json` -- users stop receiving that plugin's updates.
- Bumping `plugin.json` and forgetting README/CHANGELOG (or leaving the
  `description` describing an old shape).
- Putting skills in `.claude/skills/` for a distributed plugin (wrong;
  use `skills/` at the plugin root).
- Any Portuguese string (run a language sweep before push).
