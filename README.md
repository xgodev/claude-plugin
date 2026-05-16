# claude-plugin

A Claude Code plugin bundling reusable skills. It currently ships the
**quality-gate** skill, and is designed to grow with additional skills over
time.

## Skills

| Skill | Purpose | Docs |
|---|---|---|
| `quality-gate` | Invokes the shared [Quality Gate](https://github.com/xgodev/quality-gate) dispatcher locally before you open a PR, interprets the JSON verdict, and renders an analyzed result. The gate lives in a separate repo ([`xgodev/quality-gate`](https://github.com/xgodev/quality-gate)), cloned into `~/.quality-gate/` and pulled on every run. It fails **only** when a PR worsens a metric relative to a chosen base ref. | [`docs/quality-gate.md`](docs/quality-gate.md) |

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin
```

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

> The plugin and the gate are **separate**. `plugin update` only refreshes
> the skills in this plugin. The gate (`xgodev/quality-gate`) is pulled via
> `git` into `~/.quality-gate/` by the `quality-gate` skill on **every run**,
> so gate fixes arrive automatically without a plugin update.

## Usage

Once installed, the relevant skill triggers on natural phrases. For
`quality-gate`: ask Claude to run the quality gate before opening a PR
(e.g. "run quality gate", "rodar QG", "check quality before PR"). The skill
ensures the gate is cloned/updated and runs it against your project.

Override the gate location for local gate development with the `QG_PATH`
environment variable.

## Documentation

Per-skill docs live under [`docs/`](docs/).

## License

See the gate repository for details.
