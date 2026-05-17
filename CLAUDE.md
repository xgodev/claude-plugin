# CLAUDE.md — claude-plugin

This repo is **`claude-plugin`**: an umbrella Claude Code plugin. It
**bundles no skills of its own**. Capabilities are provided through
`dependencies` (currently `boost` and `quality-gate`) and one wired MCP
server (`playwright`). It grows by adding dependencies/MCP, not by
copying skills in.

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
- **This plugin bundles NO skill.** The `quality-gate` skill comes from
  the `quality-gate` plugin **dependency** — never copy it back in here.
  Plugin skills (if ever added) live in `skills/<name>/SKILL.md` at the
  plugin root (NOT `.claude/skills/`, which is project-local, not
  plugin-distributed). Confirmed via official docs.
- **Dependency pattern (two places, same commit).** Add the plugin name
  to `dependencies` in `.claude-plugin/plugin.json` AND re-list it in
  `.claude-plugin/marketplace.json` as
  `{name, source:{source:"url", url:"https://github.com/xgodev/<repo>.git"}, description}`
  (anonymous HTTPS, public). Mirror the existing `boost`/`quality-gate`
  entries exactly.
- **MCP servers** are declared in `.claude-plugin/plugin.json`
  `mcpServers` (e.g. `playwright` = stdio `npx -y @playwright/mcp@latest`).
- **ASCII** identifiers/commands; no accents, no em-dash (use `--`).
  Templates (if any) use `{{UPPER_SNAKE}}` placeholders only.
- **Never guess Claude Code plugin specifics.** Verify against
  https://code.claude.com/docs (plugins/skills) before asserting.

## Common mistakes

- Copying the `quality-gate` skill into this repo — it must stay a
  dependency on the `quality-gate` plugin.
- Bumping `plugin.json` and forgetting README/CHANGELOG (or leaving the
  `description` describing an old shape).
- Putting skills in `.claude/skills/` for a distributed plugin (wrong;
  use `skills/`).
- Any Portuguese string (run a language sweep before push).
