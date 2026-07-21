# Contributing to claude-plugin

This repo is the all-in-one `claude-plugin` (skills + hooks) and the single
`xgodev` marketplace. It does NOT contain the quality gate anymore -- that
moved to [`xgodev/quality-gate`](https://github.com/xgodev/quality-gate) and
ships as Docker images this plugin consumes.

## Principles

1. **Docs update in the same change.** Any change to a skill, hook, or
   structure updates every doc it affects (`README.md`, `CHANGELOG.md`,
   `CLAUDE.md`, `docs/**`) in the same commit. A doc that lies is a defect.
2. **One version for the whole bundle.** Any content change bumps the single
   plugin version -- `.claude-plugin/plugin.json`, the README `- Version:`
   line, and a `CHANGELOG.md` entry, together.
3. **English only, everywhere.** Docs, manifests, skills, comments, runtime
   output. ASCII identifiers; `--` not em-dash.
4. **Skills are gated on `writing-skills`.** Editing ANY file under `skills/`
   follows the writing-skills workflow (subagent baseline before writing) and
   obeys the `skill-rules` portability law (no absolute paths, no pinned
   versions).
5. **Hook changes run `hooks/test/*.sh`** (all green) before commit.

## The quality gate lives elsewhere

Anything about the gate's behavior -- a new language, a metric, a Dockerfile,
a ruleset, the contract -- is work in `xgodev/quality-gate`. **Open an issue
there.** That repo is maintained separately; from here we only file issues and
consume its published images. What lives HERE is only how the plugin *runs*
the gate: `skills/dev/engineering/gate.md` and `hooks/quality-gate/pr-gate.sh`
(both `docker run` the pinned image). See [`docs/quality-gate.md`](docs/quality-gate.md).

## Repo structure

```
claude-plugin/
|-- .claude-plugin/     plugin.json + marketplace.json
|-- skills/             shipped skills (dev/, ux-ui/, skill-rules/)
|-- hooks/              hooks.json + quality-gate/ + dev-rules/ + test/
|-- docs/               plugin docs (quality-gate.md, hooks.md, dev-rules.md, ...)
|-- README.md  CHANGELOG.md  CLAUDE.md
```

## Tests

```bash
hooks/test/*.sh              # hook behavior (run all before committing a hook change)
hooks/test/hooks_json_test.sh
```
