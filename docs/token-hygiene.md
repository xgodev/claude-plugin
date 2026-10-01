# Token hygiene

`tools/token-hygiene/hygiene` audits a Claude Code installation for the things
that quietly inflate the context window and the token bill, and for work left
where nobody can reach it. It is read-only unless you pass `--fix`, and it
never deletes anything.

```bash
tools/token-hygiene/hygiene                  # every check
tools/token-hygiene/hygiene memory mcp       # only these
tools/token-hygiene/hygiene --list           # what exists
tools/token-hygiene/hygiene --fix            # apply the safe repairs
```

Exit status is always 0: the report is for a person to read, not a gate.

## Why a file and not an agent

The obvious design — a scheduled agent session that looks around and tidies up
— is the expense this tool exists to prevent. Every check here is deterministic
shell and finishes in under a minute; the daily run writes plain text to a log
and costs nothing. Read the log when you want; feed it to an agent only when a
finding needs judgement.

## Checks

| Check | What it reports |
|---|---|
| `memory` | A per-project memory directory too big to carry every session. `MEMORY.md` is injected into **every** session, so its size is charged on every single request. |
| `dispatch` | Settings that let a session fan out into subagents: a `superpowers` plugin left on in a project (project settings override the user level), or the dispatch skills not turned off at the user level. Each subagent runs its own requests and bills separately. |
| `mcp` | An MCP server declared from more than one place. Every copy loads its whole tool list into every session — the duplicate is pure overhead. |
| `plugin-cache` | An installed plugin whose cache drifted from the source version it claims to be. The cache is what loads; a source fix published without a version bump never reaches it. |
| `workspaces` | Isolated agent workspaces (`.solvers/*` by default), split into the ones that are clean and fully pushed and the ones holding work the remote cannot give back. Each is a full clone, so a forgotten one costs gigabytes. |
| `unpushed` | Checkouts holding commits that exist nowhere but this machine, plus recently touched dirty trees. |

Only `plugin-cache` acts on `--fix`, and only by copying the source files over
the stale cache. Nothing is ever deleted by this tool: a workspace is reported
as removable, and a person removes it once its issue is closed.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_HYGIENE_ROOTS` / `--roots` | `$HOME/Projetos` | Colon-separated directories holding the git checkouts to audit. |
| `HYGIENE_OWNERS` | unset | Space-separated substrings a remote URL must contain. Without it, every vendored third-party clone under the roots is reported too. |
| `HYGIENE_RECENT_DAYS` | `14` | A dirty tree older than this is abandoned junk, not work in danger. Unpushed commits are reported at any age. |
| `HYGIENE_MEMORY_INDEX_BYTES` | `4000` | Size at which `MEMORY.md` is worth trimming. |
| `HYGIENE_MEMORY_DIR_BYTES` | `60000` | Size at which the whole memory directory is worth trimming. |
| `HYGIENE_WORKSPACE_DIR` | `.solvers` | Directory name holding isolated agent workspaces. |
| `CLAUDE_HOME` | `$HOME/.claude` | Where the installation lives. |

## Daily run

```bash
HYGIENE_OWNERS="myorg" tools/token-hygiene/install-daily --hour 9
```

Writes a LaunchAgent on macOS or a systemd user timer on Linux, baking the
environment in at install time, and appends each run to `$HYGIENE_LOG`
(default `~/.claude/hygiene.log`). `install-daily --uninstall` removes the
schedule and leaves the log.

## Adding a check

A check is an executable `checks/<name>.sh` that declares its single
responsibility in a header comment and calls `finding "…"` once per problem,
with any detail printed indented by six spaces. The driver collects, counts
and prints them. It reads `HYGIENE_HOME`, `HYGIENE_ROOTS` and `HYGIENE_FIX`
from the environment, and it must do nothing destructive without `--fix`.

Its tests live in `tools/token-hygiene/test/hygiene_test.sh`: they build a
sandbox installation holding one of each problem, assert every check finds it,
assert a clean sandbox reports nothing, and assert the audit writes nothing
without `--fix`. CI runs them on every PR.
