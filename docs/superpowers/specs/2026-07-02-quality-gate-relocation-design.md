# Quality Gate relocation to `tools/quality-gate/` -- design

Date: 2026-07-02
Status: approved

## Problem

The quality-gate runtime is scattered across the repo root: the `qg`
dispatcher, eight language dirs (`go/`, `java/`, `kotlin/`, `nodejs/`,
`python/`, `rust/`, `swift/`, `web/`) and `tests/` sit next to the plugin
skeleton (`skills/`, `hooks/`, `docs/`, `.claude-plugin/`), making the root
noisy and the plugin structure unclear.

## Target structure

```
tools/quality-gate/
├── qg                          # dispatcher (resolves <lang>/ via its own dirname)
├── go/ java/ kotlin/ nodejs/ python/ rust/ swift/ web/
└── tests/                      # dispatcher.bats, <lang>-qg.bats, hook-prepush.bats, helpers/
```

Root keeps only the plugin skeleton: `.claude-plugin/`, `skills/`,
`hooks/`, `docs/`, `scripts/`, README/CHANGELOG/CLAUDE.md/LICENSE/
CONTRIBUTING. `skills/` and `hooks/` cannot move -- Claude Code
auto-discovers them at those paths.

`tests/` moves inside because it is 100% quality-gate content (dispatcher,
per-language gates, and the pre-push hook that invokes the gate).

## Reference updates (same commit)

- `hooks/pre-push-gate.sh`: `$plugin/qg` -> `$plugin/tools/quality-gate/qg`.
- `skills/quality-gate/SKILL.md` + `skills/add-quality-gate/SKILL.md`:
  every `${CLAUDE_PLUGIN_ROOT}/qg` and `<lang>/` pointer. `QG_PATH`
  semantics unchanged in spirit: it points at the quality-gate dir; the
  default becomes `$CLAUDE_PLUGIN_ROOT/tools/quality-gate`.
- `tests/helpers/setup.bash`: `QG_REPO_ROOT` depth (`../..` changes) and
  the pre-push hook path (hook stays at repo-root `hooks/`).
- `docs/`: `contract.md`, `consume.md`, `quality-gate.md` (relative links
  `../<lang>/` -> `../tools/quality-gate/<lang>/`), `languages/*.md`,
  `hooks.md`.
- `CLAUDE.md`, `README.md`: documented structure.
- 3-file version discipline: `plugin.json` 1.0.0 -> 1.1.0, README
  `- Version:` line, CHANGELOG entry.

## Non-goals

- No behavior change in any gate, hook, or skill.
- No renames of the plugin, marketplace, skills, or hook files.
- No per-area plugin.json / marketplace reintroduction.

## Scope additions (approved during execution)

1. **Hook scripts grouped by area.** `hooks/hooks.json` stays at the
   standard auto-discovered path (hard rule); the scripts move to
   `hooks/quality-gate/pre-push-gate.sh` and
   `hooks/dev-rules/{red-first-guard.sh, clear-after-commit.sh, lib/}`.
   `hooks/test/` keeps covering all of them.
2. **`add-quality-gate` becomes maintainer-only.** It is a gate-repo
   maintenance tool, not an end-user capability, so it moves from the
   shipped `skills/` to the project-local `.claude/skills/` (loaded when
   working in this repo, not distributed with the plugin).

## Verification before commit

1. Full bats suite (`tools/quality-gate/tests/*.bats`).
2. `hooks/test/*.sh` all green.
3. `python3 scripts/verify_references.py`.
4. `grep -ri -E 'carrefour|bitbucket' . | grep -v '\.git/'` empty, plus a
   Portuguese-language sweep on changed files.
5. Stale-path sweep: no remaining reference to root-level `qg`, `<lang>/`
   or `tests/` paths outside `tools/quality-gate/`.
