# claude-plugin

The **all-in-one Claude Code plugin** by `xgodev`, and home of the
**`xgodev-plugins`** marketplace. One install brings every `xgodev`
capability:

- **`boost` skill set** -- grouped-index documentation skill for
  [`xgodev/boost`](https://github.com/xgodev/boost), the modular Go service
  framework. See [`docs/golang-boost.md`](docs/golang-boost.md).
- **Quality Gate** -- the `qg` dispatcher + per-language gates (Rust, Go,
  Python, Node.js, Java, Swift, Kotlin, Web), the `quality-gate` and
  `add-quality-gate` skills, and an opt-in pre-push enforcement hook. Fails
  only when a PR worsens a metric vs a base ref. Also usable as a plain CLI
  in CI. See [`docs/quality-gate.md`](docs/quality-gate.md).
- **`dev-rules`** -- macro, language-agnostic engineering-discipline skill
  (data ownership, zero coupling, RED-first TDD, docs-synced commits,
  verify-before-done), with RED-first enforcement hooks. See
  [`docs/dev-rules.md`](docs/dev-rules.md).
- **`skill-rules`** -- skill-authoring discipline: every skill must be
  portable across all developers and machines. See
  [`docs/skill-rules.md`](docs/skill-rules.md).
- **`playwright` MCP server** -- [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)
  (stdio, run on demand via `npx -y @playwright/mcp@latest`).

Skills are namespaced by the plugin name: `claude-plugin:boost`,
`claude-plugin:quality-gate`, `claude-plugin:add-quality-gate`,
`claude-plugin:dev-rules`, `claude-plugin:skill-rules`. They trigger on
natural phrases (e.g. "run quality gate" / "run QG") without the prefix.

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev-plugins
```

## Migrating from earlier layouts

**From the multi-plugin `xgodev-plugins` (claude-plugin 0.8.0):** the four
plugins (`golang-boost`, `quality-gate`, `dev-rules`, `skill-rules`) were
merged into `claude-plugin` 1.0.0. On Claude Code v2.1.193+ the marketplace's
`renames` map migrates existing installs automatically on marketplace update.
On older versions, uninstall the four plugins and install `claude-plugin`:

```text
/plugin uninstall golang-boost@xgodev-plugins
/plugin uninstall quality-gate@xgodev-plugins
/plugin uninstall dev-rules@xgodev-plugins
/plugin uninstall skill-rules@xgodev-plugins
/plugin install claude-plugin@xgodev-plugins
```

**From the retired per-repo marketplaces** (`xgodev-claude-plugin`,
`xgodev-boost`, `xgodev-quality-gate`, `xgodev-dev-rules`,
`xgodev-skill-rules`): remove them all, then add the single marketplace and
install as above:

```text
/plugin marketplace remove xgodev-claude-plugin
/plugin marketplace remove xgodev-boost
/plugin marketplace remove xgodev-quality-gate
/plugin marketplace remove xgodev-dev-rules
/plugin marketplace remove xgodev-skill-rules
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev-plugins
```

(Skip any `marketplace remove` for a marketplace you never added.)

## Update

Inside Claude Code:

```text
/plugin update claude-plugin
```

From the CLI:

```bash
claude plugin update claude-plugin@xgodev-plugins
```

If it reports `Plugin "..." not found`, specify the scope explicitly
(`--scope user`, `project`, `local`, or `managed`); `claude plugin list`
shows where it is installed.

### Auto-update

Third-party marketplaces have auto-update disabled by default. Enable it via
`/plugin` -> **Marketplaces** -> `xgodev-plugins` -> **Enable auto-update**,
or declaratively in `~/.claude/settings.json`:

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

> An update is only recognized when the `version` in `plugin.json` is
> incremented. Commits without a version bump do not trigger an update.

## Repository layout

```
.claude-plugin/        plugin.json (the single plugin) + marketplace.json (xgodev-plugins)
skills/                boost/  quality-gate/  add-quality-gate/  dev-rules/  skill-rules/
hooks/                 hooks.json (merged) + pre-push-gate.sh (QG) + red-first-guard.sh,
                       clear-after-commit.sh, lib/, test/ (dev-rules)
qg                     Quality Gate dispatcher (also a plain CLI: clone and run ./qg)
go/ java/ kotlin/      per-language gates (<lang>/qg.sh + lib/ + rules/ + test-fixtures/)
nodejs/ python/ rust/
swift/ web/
tests/                 Quality Gate bats suite
scripts/               verify_references.py (boost skill link checker)
docs/                  per-area docs + Quality Gate contract, languages, hooks
```

## Quality Gate as a CLI (no Claude Code)

```bash
git clone git@github.com:xgodev/claude-plugin.git ~/.claude-plugin
cd /path/to/your/project
~/.claude-plugin/qg --base origin/main
```

See [`docs/quality-gate.md`](docs/quality-gate.md) and
[`docs/contract.md`](docs/contract.md).

## License

MIT -- see [LICENSE](LICENSE).

- Version: 1.0.0
