# claude-plugin

The **all-in-one Claude Code plugin** by `xgodev`, and home of the
**`xgodev`** marketplace. One install brings every `xgodev`
capability:

- **`dev` skill (door)** -- one skill routing to: engineering discipline
  (`dev-rules`), the quality-gate flow, boost docs, and design. Leaves:
  grouped-index documentation for
  [`xgodev/boost`](https://github.com/xgodev/boost), the modular Go service
  framework. See [`docs/golang-boost.md`](docs/golang-boost.md).
- **Quality Gate** -- the `qg` dispatcher + per-language gates (Rust, Go,
  Python, Node.js, Java, Swift, Kotlin, Web), the gate flow inside the
  `dev` skill,
  and an opt-in PR-gate hook (`gh pr create` is gated; `git push` never is). Fails only when a PR worsens a
  metric vs a base ref. Also usable as a plain CLI in CI. See
  [`docs/quality-gate.md`](docs/quality-gate.md).
- **`dev-rules`** -- macro, language-agnostic engineering-discipline skill
  (data ownership, zero coupling, RED-first TDD, docs-synced commits,
  verify-before-done), with RED-first enforcement hooks. See
  [`docs/dev-rules.md`](docs/dev-rules.md).
- **`skill-rules`** -- skill-authoring discipline: every skill must be
  portable across all developers and machines. See
  [`docs/skill-rules.md`](docs/skill-rules.md).
- **`ux-ui`** -- design door skill: a searchable catalog (palettes,
  styles, typography, charts, UX guidelines, per-framework patterns)
  plus UX methodology references. Catalog data is queried by a bundled
  engine, never loaded into context. See
  [`docs/ux-catalog.md`](docs/ux-catalog.md).
- **`ux-ui` (design door)** -- a thin routing skill so pure design tasks
  find the catalog directly; it lands on the same `dev/design/` content.
- **Dependency: [`superpowers`](https://github.com/obra/superpowers)** --
  core skills library by Jesse Vincent (TDD, debugging, collaboration
  patterns), resolved from the official `claude-plugins-official`
  marketplace and auto-installed with `claude-plugin`. An existing
  `superpowers@claude-plugins-official` install satisfies it -- no
  duplicate copy.

Skills are namespaced by the plugin name: `claude-plugin:dev`,
`claude-plugin:ux-ui` (thin design door), `claude-plugin:skill-rules`. They trigger on
natural phrases (e.g. "run quality gate" / "run QG") without the prefix. (The `add-quality-gate`
skill is maintainer-only and lives project-local in this repo -- it is
not shipped with the plugin.)

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin@xgodev
```

The `superpowers` dependency auto-installs with `claude-plugin`, no
extra step: it resolves from `claude-plugins-official` (preconfigured in
Claude Code; an existing install satisfies it).

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

Measured cost of installing this plugin, A/B-tested with Claude Code
(`claude -p` in the same fresh project with the plugin disabled vs
enabled; total context = `input + cache_creation + cache_read` tokens of
the first request):

| Configuration | Total context (first request) |
|---|---|
| Claude Code baseline, plugin disabled | ~25,123 tokens |
| With `claude-plugin` enabled | ~25,427 tokens |
| **Plugin overhead, per session** | **~304 tokens (+1.2%)** |

That always-on cost is ONLY the name + description lines of the two
bundled skills plus plugin registration metadata. Everything else is
pay-per-use:

| Component | Always-on | Loaded when |
|---|---|---|
| `dev` description (door: engineering, gate, boost, design) | ~150 tokens | every session |
| `ux-ui` description (thin design door) | ~85 tokens | every session |
| `skill-rules` description | ~40 tokens | every session |
| `dev` router SKILL.md + the leaf it routes to | 0 | only when the skill fires |
| Hooks (PR gate, RED-first, main-folder, line-cap, issue reminder) | 0 | never (run as processes) |
| MCP servers | 0 | none bundled |

## Repository layout

```
.claude-plugin/        plugin.json (the single plugin) + marketplace.json (xgodev)
skills/                dev/{SKILL.md router, engineering/, golang/, design/}
                       ux-ui/ (thin design door -> dev/design)  skill-rules/ (shipped)
.claude/skills/        add-quality-gate/ (maintainer-only, project-local)
hooks/                 hooks.json (merged registry) + test/; scripts grouped by area:
                       quality-gate/pr-gate.sh, dev-rules/{red-first-guard.sh,
                       main-folder-guard.sh, line-cap-guard.sh,
                       issue-comment-reminder.sh, clear-after-commit.sh, lib/}
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

- Version: 1.9.0
