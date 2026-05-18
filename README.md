# claude-plugin

An umbrella Claude Code plugin. It **bundles no skills of its own** —
capabilities are provided through plugin `dependencies` (currently
[`quality-gate`](https://github.com/xgodev/quality-gate),
[`dev-rules`](https://github.com/xgodev/dev-rules) and
[`boost`](https://github.com/xgodev/boost)) plus one wired MCP server
(`playwright`). It grows by adding dependencies, not by copying skills in.

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin
```

## Dependencies

Installing `claude-plugin` automatically pulls:

- **`boost`** — same-marketplace plugin dependency, re-listed in
  `marketplace.json` with an anonymous HTTPS clone of
  [`xgodev/boost`](https://github.com/xgodev/boost). Declared in
  `plugin.json` `dependencies`.
- **`quality-gate`** — same-marketplace plugin dependency, re-listed in
  `marketplace.json` with an anonymous HTTPS clone of
  [`xgodev/quality-gate`](https://github.com/xgodev/quality-gate). Declared
  in `plugin.json` `dependencies`. This is where the `quality-gate` skill now
  ships from (it is no longer bundled in this repo).
- **`dev-rules`** — same-marketplace plugin dependency, re-listed in
  `marketplace.json` with an anonymous HTTPS clone of
  [`xgodev/dev-rules`](https://github.com/xgodev/dev-rules). Declared in
  `plugin.json` `dependencies`. Macro, language-agnostic engineering-
  discipline skill applied before writing/editing/refactoring any code.

It also wires up one MCP server:

- **`playwright`** — the [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)
  server (stdio, run on demand via `npx -y @playwright/mcp@latest`).
  Declared in `plugin.json` `mcpServers`; no manual setup required.

## Update

Inside Claude Code:

```text
/plugin update claude-plugin
```

From the CLI:

```bash
claude plugin update claude-plugin@claude-plugin
```

If it reports `Plugin "..." not found`, specify the scope explicitly:

```bash
claude plugin update claude-plugin@claude-plugin --scope user   # or: project | local | managed
```

Use `claude plugin list` to find the scope where the plugin is installed.

### Auto-update

Claude Code checks for plugin updates at startup, but **third-party
marketplaces have auto-update disabled by default** — only Anthropic's
official marketplaces update on their own. To enable it:

Interactive, inside Claude Code:

```text
/plugin
```

→ **Marketplaces** → select `claude-plugin` → **Enable auto-update**.

Or declaratively, in `~/.claude/settings.json` (global) — add
`"autoUpdate": true` to the marketplace entry under
`extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "claude-plugin": {
      "source": {
        "source": "git",
        "url": "git@github.com:xgodev/claude-plugin.git"
      },
      "autoUpdate": true
    }
  }
}
```

The same works in a project's `.claude/settings.json` if you want to pin
auto-update for the team via the repo. Restart Claude Code for the change to
take effect.

> An update is only recognized when the `version` in `plugin.json` is
> incremented. Commits without a version bump do not trigger an update —
> even with auto-update on, Claude Code reports "already at latest".

> The `quality-gate` skill is provided by the `quality-gate` plugin
> dependency, which packages the gate with it. Updating that dependency
> (`plugin update`) refreshes both the skill and its bundled gate.

## Usage

Once installed, the relevant skill triggers on natural phrases. For
`quality-gate`: ask Claude to run the quality gate before opening a PR
(e.g. "run quality gate", "run QG", "check quality before PR").

## Documentation

The `quality-gate` skill and its docs live in the
[`xgodev/quality-gate`](https://github.com/xgodev/quality-gate) plugin
repository.

## License

See the gate repository for details.
