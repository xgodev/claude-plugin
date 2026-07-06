# dev-rules

A single macro, **language-agnostic engineering-discipline** Claude Code
plugin. It encodes how to write, edit, and refactor code well in any
language -- the methodology and decision rules a mechanical gate cannot
measure (data ownership, zero coupling, single source of truth, RED-first
TDD, docs-synced commits, honest failure, verify-before-done,
concurrency-first design).

It is the companion to the [Quality Gate](quality-gate.md) bundled in this
same plugin: the gate catches mechanical metric regressions (fmt, lint,
build, test, complexity, coverage); `dev-rules` governs the judgment the
gate cannot see. Use them together, not interchangeably.

It is a **discipline-enforcing** skill: rigid, concise, applied **before**
writing -- not a passive reference skimmed after the fact.

## Install

`dev-rules` ships as part of the all-in-one `claude-plugin` -- see the
[repo README](../README.md) for install and update instructions.

## Enforcement hooks (shipped with the plugin)

`dev-rules` ships language-agnostic hooks that fire in every project where the
plugin is enabled. They make LAW 1 (RED-first) and LAW 13 (spec-driven flow)
deterministic instead of advisory.

**Requirement:** `jq` on `PATH`. Without it the hooks degrade to warn + allow
(they never block when they cannot inspect the call).

**State machine** (sentinels live under `<project>/.dev-rules/`, also honored
under `.solvers/*/.dev-rules/`):

| Sentinel | Production READ | Production EDIT |
|---|---|---|
| none (bug default) | blocked | blocked |
| `.mode-feature` | allowed | allowed |
| `.red-first-unlocked` | allowed | allowed |

Test files, docs, and config are never blocked.

**Bug flow:** brainstorm with the user -> write the failing test (allowed) ->
see it RED -> `touch .dev-rules/.red-first-unlocked` -> read code and fix.

**Feature flow:** brainstorm -> `touch .dev-rules/.mode-feature` -> read code,
plan (`writing-plans`), and write the code. Red-first is the bug gate, so feature
mode unlocks edits too; TDD per unit is still expected, governed by the plan and
review rather than the hook.

A cycle-closing commit (`fix(`/`feat(`/`bugfix(`/`Fix #`/`Fixes #`) auto-clears
both sentinels, so the next cycle re-brainstorms and re-REDs.

**Per-repo config / opt-out (`.dev-rules.json` at the repo root):**

```json
{
  "enabled": true,
  "production_globs": ["src/**", "internal/**", "crates/**/src/**"],
  "test_globs": ["**/*_test.*", "**/tests/**", "**/*.spec.*"],
  "main_folder_guard": false,
  "line_cap_guard": true,
  "line_cap_default": 500,
  "line_caps": { ".go": 600, ".ts": 400 }
}
```

`"enabled": false` disables all gating for the project. Omit the file to use
built-in detection (production segments: `src lib app cmd internal pkg crates
domain`, minus test/docs/config).

### main-folder guard (opt-in)

With `"main_folder_guard": true`, the plugin enforces the isolated-workspace
flow: `Edit`/`Write` targeting files in the MAIN working tree is denied, and
so are bare mutating VCS commands (`git commit/push/merge/rebase/reset/
checkout/...`) whose working tree is the main folder -- work happens inside
`.solvers/<task-name>/` clones (`git -C .solvers/<name> ...` and any command
referencing `.solvers/` pass). Keyed off what the operation TARGETS, so a
session rooted in the main folder can still set up and drive the clone.
Reads/greps, `git status/log/diff/fetch`, `git worktree add`/`clone`, and
writes to `.dev-rules/`, `.claude/`, or outside the project are never
blocked. Default: OFF (projects not using the `.solvers/` convention are
unaffected).

### line-cap guard (on by default)

Denies `Edit`/`Write` that would GROW a source file already over its line
cap, forcing a split BEFORE the file gets bigger. Shrinking edits and split
rewrites always pass, as do new files, test files, and docs/config. Caps:
per-extension via `"line_caps"`, global default via `"line_cap_default"`
(built-in default: 500). Disable with `"line_cap_guard": false`.
