# claude-plugin

An umbrella Claude Code plugin by `xgodev`. It **bundles no skills of
its own** -- capabilities are provided through **cross-marketplace
plugin dependencies**:

- [`boost@xgodev-boost`](https://github.com/xgodev/boost)
- [`quality-gate@xgodev-quality-gate`](https://github.com/xgodev/quality-gate)
- [`dev-rules@xgodev-dev-rules`](https://github.com/xgodev/dev-rules)

It also wires one MCP server (`playwright`). Installing `claude-plugin`
auto-installs the three dependencies (each lives in its own marketplace
and is allow-listed via this marketplace's
`allowCrossMarketplaceDependenciesOn`).

> Requires Claude Code v2.1.110+ (cross-marketplace dependency support).

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev-claude-plugin
```

Claude Code resolves each dependency by adding its standalone
marketplace (`xgodev-boost`, `xgodev-quality-gate`, `xgodev-dev-rules`)
on demand. The install output lists the auto-installed dependencies at
the end.

## What it provides

- **Dependency plugins** (auto-installed):
  - `boost` -- the `xgodev/boost` framework skills.
  - `quality-gate` -- the `quality-gate` skill + gate dispatcher.
  - `dev-rules` -- language-agnostic engineering-discipline skill.
- **`playwright`** MCP server -- the [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)
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
marketplaces have auto-update disabled by default** -- only Anthropic's
official marketplaces update on their own. To enable it:

Interactive, inside Claude Code:

```text
/plugin
```

-> **Marketplaces** -> select `xgodev-claude-plugin` -> **Enable auto-update**.

Or declaratively, in `~/.claude/settings.json` (global) -- add
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
auto-update for the team via the repo. Restart Claude Code for the
change to take effect.

> An update is only recognized when the `version` in `plugin.json` is
> incremented. Commits without a version bump do not trigger an update
> -- even with auto-update on, Claude Code reports "already at latest".

## Usage

Once installed, the dependency plugins' skills trigger on natural
phrases. For `quality-gate`: ask Claude to run the quality gate before
opening a PR (e.g. "run quality gate", "run QG"). The `playwright` MCP
server is available to Claude under the `mcp__playwright__*` tool
namespace.

## License

MIT (no source files; configuration only).
