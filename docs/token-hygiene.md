# Token hygiene

`tools/token-hygiene/hygiene` audits a Claude Code installation for the things
that quietly inflate the context window, and reads the token bill itself from
the session transcripts. It is read-only unless you pass `--fix`, and it
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
| `dispatch` | A project carrying the subagent-dispatch plugin in every session without dispatching anything. Fanning out is legitimate work when it is asked for — each subagent just runs its own requests and bills separately — so the defect is not "enabled", it is **enabled and idle**. Usage is read from that project's own session transcripts. |
| `mcp` | An MCP server declared from more than one place. Every copy loads its whole tool list into every session — the duplicate is pure overhead. |
| `plugin-cache` | An installed plugin whose cache drifted from the source version it claims to be. The cache is what loads; a source fix published without a version bump never reaches it. |
| `usage` | The bill itself, per day, from the session transcripts: subagents taking too large a share, a context per request so big that sessions run too long before compacting, and a daily total over budget. The other checks watch the causes; this one shows whether they matter. Streaming writes one message over several lines, so each message is counted once. |

Only `plugin-cache` acts on `--fix`, and only by copying the source files over
the stale cache. Nothing is ever deleted by this tool.

Git state (unpushed commits, leftover clones) is not a token problem and is
out of scope.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_HYGIENE_ROOTS` / `--roots` | `$HOME/Projetos` | Colon-separated directories holding the projects whose `.claude/` settings `dispatch` audits. |
| `HYGIENE_IDLE_DAYS` | `30` | How long a project may carry the dispatch plugin without dispatching anything before it is reported. |
| `HYGIENE_MEMORY_INDEX_BYTES` | `4000` | Size at which `MEMORY.md` is worth trimming. |
| `HYGIENE_MEMORY_DIR_BYTES` | `60000` | Size at which the whole memory directory is worth trimming. |
| `HYGIENE_USAGE_DAYS` | `7` | How many days of transcripts `usage` reads. |
| `HYGIENE_USAGE_SUBAGENT_PCT` | `20` | Subagent share of a day's tokens worth reporting. |
| `HYGIENE_USAGE_CTX_TOKENS` | `200000` | Average context per request worth reporting. |
| `HYGIENE_USAGE_DAY_TOKENS` | `1000000000` | Daily input-token budget; `0` turns this finding off. |
| `CLAUDE_HOME` | `$HOME/.claude` | Where the installation lives. |

## Daily run

```bash
tools/token-hygiene/install-daily --hour 9
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
