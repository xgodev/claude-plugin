# Quality Gate relocation to `tools/dev/quality-gate/` -- design

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
tools/dev/quality-gate/
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

- `hooks/pre-push-gate.sh`: `$plugin/qg` -> `$plugin/tools/dev/quality-gate/qg`.
- `skills/quality-gate/SKILL.md` + `skills/add-quality-gate/SKILL.md`:
  every `${CLAUDE_PLUGIN_ROOT}/qg` and `<lang>/` pointer. `QG_PATH`
  semantics unchanged in spirit: it points at the quality-gate dir; the
  default becomes `$CLAUDE_PLUGIN_ROOT/tools/dev/quality-gate`.
- `tests/helpers/setup.bash`: `QG_REPO_ROOT` depth (`../..` changes) and
  the pre-push hook path (hook stays at repo-root `hooks/`).
- `docs/`: `contract.md`, `consume.md`, `quality-gate.md` (relative links
  `../<lang>/` -> `../tools/dev/quality-gate/<lang>/`), `languages/*.md`,
  `hooks.md`.
- `CLAUDE.md`, `README.md`: documented structure.
- 3-file version discipline: `plugin.json` 1.0.0 -> 1.1.0, README
  `- Version:` line, CHANGELOG entry.

## Non-goals

- No behavior change in any gate, hook, or skill.
- No renames of the plugin, marketplace, skills, or hook files.
- No per-area plugin.json / marketplace reintroduction.

## Verification before commit

1. Full bats suite (`tools/dev/quality-gate/tests/*.bats`).
2. `hooks/test/*.sh` all green.
3. `python3 scripts/verify_references.py`.
4. `grep -ri -E 'carrefour|bitbucket' . | grep -v '\.git/'` empty, plus a
   Portuguese-language sweep on changed files.
5. Stale-path sweep: no remaining reference to root-level `qg`, `<lang>/`
   or `tests/` paths outside `tools/dev/quality-gate/`.
