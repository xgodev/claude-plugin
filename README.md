# claude-plugin

Home of **`xgodev-plugins`** -- the single `xgodev` Claude Code
marketplace -- and of the umbrella plugin **`claude-plugin`**.

The marketplace lists every `xgodev` plugin; each plugin ships from its
own repository via a GitHub source:

- [`golang-boost`](https://github.com/xgodev/boost-claude) -- skills for
  the [`xgodev/boost`](https://github.com/xgodev/boost) framework.
- [`quality-gate`](https://github.com/xgodev/quality-gate) -- the
  `quality-gate` skill + gate dispatcher.
- [`dev-rules`](https://github.com/xgodev/dev-rules) --
  language-agnostic engineering-discipline skill.
- [`skill-rules`](https://github.com/xgodev/skill-rules) --
  skill-authoring discipline: every skill must be portable across all
  developers and machines.

The umbrella plugin **bundles no skills of its own** -- it declares the
four plugins above as dependencies (resolved within this same
marketplace, so installing it auto-installs all four) and wires one MCP
server (`playwright`).

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev-plugins
```

The install output lists the auto-installed dependencies at the end.

Plugins can also be installed individually from the same marketplace:

```text
/plugin install dev-rules@xgodev-plugins
/plugin install quality-gate@xgodev-plugins
/plugin install skill-rules@xgodev-plugins
/plugin install golang-boost@xgodev-plugins
```

## Migrating from the per-repo marketplaces

Before `claude-plugin` 0.8.0, each plugin was its own marketplace
(`xgodev-claude-plugin`, `xgodev-boost`, `xgodev-quality-gate`,
`xgodev-dev-rules`, `xgodev-skill-rules`) and the umbrella pulled the
others via cross-marketplace dependencies. Those marketplaces are
retired. If you installed the old way, remove them and re-add the single
marketplace:

```text
/plugin uninstall claude-plugin@xgodev-claude-plugin
/plugin marketplace remove xgodev-claude-plugin
/plugin marketplace remove xgodev-boost
/plugin marketplace remove xgodev-quality-gate
/plugin marketplace remove xgodev-dev-rules
/plugin marketplace remove xgodev-skill-rules
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev-plugins
```

(Skip any `marketplace remove` for a marketplace you never added.)

## What it provides

- **Dependency plugins** (auto-installed with the umbrella):
  - `golang-boost` -- skills for the `xgodev/boost` framework, shipped
    from [`xgodev/boost-claude`](https://github.com/xgodev/boost-claude).
  - `quality-gate` -- the `quality-gate` skill + gate dispatcher.
  - `dev-rules` -- language-agnostic engineering-discipline skill.
  - `skill-rules` -- skill-authoring discipline: every skill must be
    portable across all developers and machines.
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
claude plugin update claude-plugin@xgodev-plugins
```

If it reports `Plugin "..." not found`, specify the scope explicitly:

```bash
claude plugin update claude-plugin@xgodev-plugins --scope user   # or: project | local | managed
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

-> **Marketplaces** -> select `xgodev-plugins` -> **Enable auto-update**.

Or declaratively, in `~/.claude/settings.json` (global) -- add
`"autoUpdate": true` to the marketplace entry under
`extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "xgodev-plugins": {
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

> An update is only recognized when the `version` in a plugin's
> `plugin.json` is incremented. Commits without a version bump do not
> trigger an update -- even with auto-update on, Claude Code reports
> "already at latest".

## Usage

Once installed, the dependency plugins' skills trigger on natural
phrases. For `quality-gate`: ask Claude to run the quality gate before
opening a PR (e.g. "run quality gate", "run QG"). The `playwright` MCP
server is available to Claude under the `mcp__playwright__*` tool
namespace.

## License

MIT (no source files; configuration only).
