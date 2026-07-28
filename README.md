# claude-plugin

The **all-in-one Claude Code plugin** by `xgodev`, and home of the
**`xgodev`** marketplace. One install brings every `xgodev`
capability:

- **`dev` skill (door)** -- one skill routing to: engineering discipline
  (`dev-rules`), the quality-gate flow, boost docs, and Rust discipline. Leaves:
  grouped-index documentation for
  [`xgodev/boost`](https://github.com/xgodev/boost), the modular Go service
  framework. See [`docs/golang-boost.md`](docs/golang-boost.md).
- **Quality Gate** -- the gate flow inside the `dev` skill plus an opt-in
  PR-gate hook (`gh pr create` is gated; `git push` never is). The gate itself
  lives in [`xgodev/quality-gate`](https://github.com/xgodev/quality-gate) and
  ships as per-language Docker images (`ghcr.io/xgodev/quality-gate/<lang>`);
  this plugin runs the pinned image (`docker` required, fails open when
  absent). Fails only when a change worsens a metric vs a base ref. A repo can
  turn the PR-gate hook off per language with a `.qg-hook.json`
  (`{"pr_gate": {"rust": false}}`) when a local gate is too slow to run on
  every PR and CI already enforces it -- not a bypass. See
  [`docs/quality-gate.md`](docs/quality-gate.md).
- **`dev-rules`** -- macro, language-agnostic engineering-discipline skill
  (data ownership, zero coupling, RED-first TDD, docs-synced commits,
  verify-before-done), with RED-first enforcement hooks. See
  [`docs/dev-rules.md`](docs/dev-rules.md).
- **`skill-rules`** -- skill-authoring discipline: every skill must be
  portable across all developers and machines. See
  [`docs/skill-rules.md`](docs/skill-rules.md).
- **`ux-ui`** -- the design skill: a searchable catalog (palettes,
  styles, typography, charts, UX guidelines, per-framework patterns)
  plus UX methodology references. Catalog data is queried by a bundled
  engine, never loaded into context. See
  [`docs/ux-catalog.md`](docs/ux-catalog.md).
- **Dependency: [`superpowers`](https://github.com/obra/superpowers)** --
  core skills library by Jesse Vincent (TDD, debugging, collaboration
  patterns), resolved from the official `claude-plugins-official`
  marketplace and auto-installed with `claude-plugin`. An existing
  `superpowers@claude-plugins-official` install satisfies it -- no
  duplicate copy.

Skills are namespaced by the plugin name: `claude-plugin:dev`,
`claude-plugin:ux-ui` (design), `claude-plugin:skill-rules`. They trigger on
natural phrases (e.g. "run quality gate" / "run QG") without the prefix.

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
| `dev` description (door: engineering, gate, boost, rust, design) | ~110 tokens | every session |
| `ux-ui` description (design) | ~85 tokens | every session |
| `skill-rules` description | ~40 tokens | every session |
| `dev` router SKILL.md + the leaf it routes to | 0 | only when the skill fires |
| Hooks (PR gate, RED-first, main-folder, line-cap, issue reminder, mode prompt) | 0 | never (run as processes) |
| MCP servers | 0 | none bundled |

## Repository layout

```
.claude-plugin/        plugin.json (the single plugin) + marketplace.json (xgodev)
skills/                dev/{SKILL.md router, engineering/, golang/boost/, rust/}
                       ux-ui/ (design: catalog + references)  skill-rules/ (shipped)
hooks/                 hooks.json (merged registry) + test/; scripts grouped by area:
                       quality-gate/pr-gate.sh, dev-rules/{red-first-guard.sh,
                       main-folder-guard.sh, line-cap-guard.sh,
                       issue-comment-reminder.sh, mode-prompt.sh,
                       clear-after-commit.sh, lib/}
scripts/               verify_references.py (boost skill link checker)
                       verify_config_roots.py (boost config namespaces vs source)
docs/                  per-area docs (quality-gate, hooks, dev-rules, ...)
```

The quality gate is not bundled here -- it lives in
[`xgodev/quality-gate`](https://github.com/xgodev/quality-gate) as Docker
images. See [`docs/quality-gate.md`](docs/quality-gate.md).

## License

MIT -- see [LICENSE](LICENSE).

- Version: 1.18.0
