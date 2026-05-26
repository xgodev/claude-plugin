# claude-plugin

A standalone Claude Code plugin by `xgodev`. It bundles no skills of its
own; it just wires one MCP server (`playwright`). No plugin dependencies.

Other `xgodev` plugins live in their own marketplaces and are installed
independently (e.g. `quality-gate@xgodev-quality-gate`,
`dev-rules@xgodev-dev-rules`, `boost@xgodev-boost`).

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev-claude-plugin
```

## What it provides

- **`playwright`** MCP server — the [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)
  server (stdio, run on demand via `npx -y @playwright/mcp@latest`).
  Declared in `plugin.json` `mcpServers`; no manual setup required.

## Update

Inside Claude Code:

```text
/plugin update claude-plugin
```

From the CLI:

```bash
claude plugin update claude-plugin@xgodev-claude-plugin
```

If it reports `Plugin "..." not found`, specify the scope explicitly:

```bash
claude plugin update claude-plugin@xgodev-claude-plugin --scope user   # or: project | local | managed
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
    "xgodev-claude-plugin": {
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

## Usage

The `playwright` MCP server is available to Claude once installed. Tools
appear under the `mcp__playwright__*` namespace.

## License

MIT (no source files; configuration only).
