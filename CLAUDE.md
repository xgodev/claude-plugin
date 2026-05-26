# CLAUDE.md — claude-plugin

This repo is **`claude-plugin`**: a standalone Claude Code plugin by
`xgodev`. It bundles no skills and declares **no plugin dependencies**.
Its only job is to wire one MCP server (`playwright`). Other `xgodev`
plugins live in their own marketplaces and are installed independently.

These are hard rules. Read them before changing anything so a future
session does not repeat past mistakes.

## Hard rules

- **Docs are ALWAYS updated in the same change. No exceptions.** Any
  change to structure, dependencies, MCP, or version updates — in the
  **same commit** — `README.md`, `CHANGELOG.md`, this `CLAUDE.md`, and the
  `.claude-plugin/plugin.json` `description` if it no longer matches
  reality. A manifest or doc that lies about the project is a defect, not
  a follow-up. Before committing: "what doc does this change make false?"
  — fix it now.
- **3-file version discipline.** A version change moves together, same
  commit: `.claude-plugin/plugin.json` `version`, the README `- Version:`
  line (if present), and a `CHANGELOG.md` entry. Verify they match before
  committing.
- **English only. Everywhere.** README, CHANGELOG, CLAUDE.md, manifests,
  descriptions. Public OSS — no Portuguese anywhere.
- **Zero proprietary / internal references.** No `carrefour`,
  `bitbucket`, internal names/URLs. Before push:
  `grep -ri -E 'carrefour|bitbucket' . --include='*' | grep -v '\.git/'`
  must be empty.
- **This plugin bundles NO skill and NO plugin dependency.** Skills (if
  ever added) live in `skills/<name>/SKILL.md` at the plugin root (NOT
  `.claude/skills/`, which is project-local, not plugin-distributed).
- **No dependency / no re-listing.** Do NOT add other `xgodev` plugins
  (`quality-gate`, `dev-rules`, `boost`) as `dependencies` here and do
  NOT re-list them in `marketplace.json`. They are independent
  marketplaces (e.g. `quality-gate@xgodev-quality-gate`) and the user
  installs them directly. Coupling them via this umbrella is what caused
  marketplace ID collisions (`quality-gate@xgodev` existed only as a
  side-effect of the re-listing) and was removed in 0.5.0.
- **MCP servers** are declared in `.claude-plugin/plugin.json`
  `mcpServers` (e.g. `playwright` = stdio `npx -y @playwright/mcp@latest`).
  Adding/removing/replacing an MCP server is the typical change in this
  repo; anything else is suspect.
- **ASCII** identifiers/commands; no accents, no em-dash (use `--`).
  Templates (if any) use `{{UPPER_SNAKE}}` placeholders only.
- **Never guess Claude Code plugin specifics.** Verify against
  https://code.claude.com/docs (plugins/skills) before asserting.

## Common mistakes

- Re-introducing `dependencies` / re-listings in `marketplace.json` to
  "bundle other xgodev plugins" — that is exactly what 0.5.0 removed.
  Other `xgodev` plugins are independent marketplaces.
- Bumping `plugin.json` and forgetting README/CHANGELOG (or leaving the
  `description` describing an old shape).
- Putting skills in `.claude/skills/` for a distributed plugin (wrong;
  use `skills/` at the plugin root).
- Any Portuguese string (run a language sweep before push).
