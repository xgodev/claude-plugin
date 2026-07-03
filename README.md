# claude-plugin

The **all-in-one Claude Code plugin** by `xgodev`, and home of the
**`xgodev`** marketplace. One install brings every `xgodev`
capability:

- **`boost` skill set** -- grouped-index documentation skill for
  [`xgodev/boost`](https://github.com/xgodev/boost), the modular Go service
  framework. See [`docs/golang-boost.md`](docs/golang-boost.md).
- **Quality Gate** -- the `qg` dispatcher + per-language gates (Rust, Go,
  Python, Node.js, Java, Swift, Kotlin, Web), the `quality-gate` skill,
  and an opt-in pre-push enforcement hook. Fails only when a PR worsens a
  metric vs a base ref. Also usable as a plain CLI in CI. See
  [`docs/quality-gate.md`](docs/quality-gate.md).
- **`dev-rules`** -- macro, language-agnostic engineering-discipline skill
  (data ownership, zero coupling, RED-first TDD, docs-synced commits,
  verify-before-done), with RED-first enforcement hooks. See
  [`docs/dev-rules.md`](docs/dev-rules.md).
- **`skill-rules`** -- skill-authoring discipline: every skill must be
  portable across all developers and machines. See
  [`docs/skill-rules.md`](docs/skill-rules.md).
- **Dependency: [`ux-ui-mastery`](https://github.com/xgodev/ux-ui-mastery)**
  -- UX/UI design mastery plugin by Design Tribe Republic (19 skills, 10
  commands), served from the `xgodev` fork carrying a Claude Code
  manifest fix, listed in the `xgodev` marketplace and auto-installed
  with `claude-plugin`.
- **Dependency: [`superpowers`](https://github.com/obra/superpowers)** --
  core skills library by Jesse Vincent (TDD, debugging, collaboration
  patterns), resolved from the official `claude-plugins-official`
  marketplace and auto-installed with `claude-plugin`. An existing
  `superpowers@claude-plugins-official` install satisfies it -- no
  duplicate copy.

Skills are namespaced by the plugin name: `claude-plugin:boost`,
`claude-plugin:quality-gate`, `claude-plugin:dev-rules`,
`claude-plugin:skill-rules`. They trigger on natural phrases (e.g. "run
quality gate" / "run QG") without the prefix. (The `add-quality-gate`
skill is maintainer-only and lives project-local in this repo -- it is
not shipped with the plugin.)

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev
```

Dependencies auto-install with `claude-plugin`, no extra step:
`superpowers` resolves from `claude-plugins-official` (preconfigured in
Claude Code; an existing install satisfies it) and `ux-ui-mastery` from
the `xgodev` marketplace itself.

## Update

Inside Claude Code:

```text
/plugin update claude-plugin
```

From the CLI:

```bash
claude plugin update claude-plugin@xgodev
```

If it reports `Plugin "..." not found`, specify the scope explicitly
(`--scope user`, `project`, `local`, or `managed`); `claude plugin list`
shows where it is installed.

### Auto-update

Third-party marketplaces have auto-update disabled by default. Enable it via
`/plugin` -> **Marketplaces** -> `xgodev` -> **Enable auto-update**,
or declaratively in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "xgodev": {
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

## Context-window overhead

Measured cost of installing this plugin, A/B-tested with Claude Code 2.1.199
(`claude -p` in two identical fresh projects, one with the plugin installed
at project scope, total context = `input + cache_creation + cache_read`
tokens of the first request; 2 runs each, +/-11 tokens run-to-run noise):

| Configuration | Total context (first request) |
|---|---|
| Claude Code baseline, no plugin | ~26,600 tokens |
| With `claude-plugin` installed | ~26,970 tokens |
| **Plugin overhead, per session** | **~370 tokens (+1.4%)** |

That ~370 tokens is the WHOLE always-on cost: the name + description lines
of the 4 bundled skills plus plugin registration metadata. Everything else
is pay-per-use:

| Component | Always-on | Loaded when |
|---|---|---|
| `boost` description | ~55 tokens | every session |
| `quality-gate` description | ~55 tokens | every session |
| `skill-rules` description | ~40 tokens | every session |
| `dev-rules` description | ~25 tokens | every session |
| `quality-gate` SKILL.md (~2.5k words) | 0 | only when the skill fires |
| `dev-rules` SKILL.md (~4.3k words) | 0 | only when the skill fires |
| `boost` SKILL.md index + per-component references | 0 | only when the skill fires |
| Hooks (pre-push gate, RED-first) | 0 | never (run as processes) |
| MCP servers | 0 | none bundled |

## Repository layout

```
.claude-plugin/        plugin.json (the single plugin) + marketplace.json (xgodev)
skills/                boost/  quality-gate/  dev-rules/  skill-rules/ (shipped)
.claude/skills/        add-quality-gate/ (maintainer-only, project-local)
hooks/                 hooks.json (merged registry) + test/; scripts grouped by area:
                       quality-gate/pre-push-gate.sh, dev-rules/{red-first-guard.sh,
                       clear-after-commit.sh, lib/}
tools/quality-gate/
                       qg (dispatcher; also a plain CLI), per-language gates
                       (<lang>/qg.sh + lib/ + rules/ + test-fixtures/ for go, java,
                       kotlin, nodejs, python, rust, swift, web), tests/ (bats suite)
scripts/               verify_references.py (boost skill link checker)
docs/                  per-area docs + Quality Gate contract, languages, hooks
```

## Quality Gate as a CLI (no Claude Code)

```bash
git clone git@github.com:xgodev/claude-plugin.git ~/.claude-plugin
cd /path/to/your/project
~/.claude-plugin/tools/quality-gate/qg --base origin/main
```

See [`docs/quality-gate.md`](docs/quality-gate.md) and
[`docs/contract.md`](docs/contract.md).

## License

MIT -- see [LICENSE](LICENSE).

- Version: 1.1.9
