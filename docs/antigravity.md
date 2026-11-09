# Google Antigravity Integration

The all-in-one `claude-plugin` repository provides first-class, dual-target
support for **Google Antigravity** (both Antigravity CLI `agy` and the Antigravity IDE).

The single repository acts as the single source of truth:
- **Skills** (`dev`, `ux-ui`, `skill-rules`) are loaded directly by Antigravity
  with native progressive disclosure.
- **Hooks** (`hooks.json` at the repository root) route lifecycle events
  through `hooks/antigravity-adapter.sh`, which dynamically executes the
  canonical definitions in `hooks/hooks.json`.
- **Project discipline state** (`.dev-rules/`, `.dev-rules.json`, `.qg.yaml`,
  `.qg-hook.json`) is 100% shared between Claude Code and Antigravity:
  sentinels unlocked in one harness are recognized in the other, and commits in
  either re-arm the guards.

---

## Installation

### Global (All Projects)

Link the clone into your Antigravity global plugins directory:

```bash
./scripts/install-antigravity.sh
```

This creates a symlink at:
`~/.gemini/config/plugins/claude-plugin -> /path/to/claude-plugin`

Restart Antigravity or the `agy` CLI to discover the plugin. Any `git pull` in
this repository updates the plugin live for both Claude Code and Antigravity.

### Project-Specific

Link into a specific project workspace:

```bash
./scripts/install-antigravity.sh --project /path/to/project
```

This installs into `<project>/.agents/plugins/claude-plugin` without touching
global configuration.

### Uninstall

```bash
./scripts/install-antigravity.sh --uninstall
# Or for a specific project:
./scripts/install-antigravity.sh --uninstall --project /path/to/project
```

---

## Architecture & Event Mapping

The root `hooks.json` registers Antigravity lifecycle events and delegates to
`hooks/antigravity-adapter.sh`:

```text
Antigravity Runtime (protojson stdin)
       │
       ▼
   hooks.json (root)
       │
       ▼
hooks/antigravity-adapter.sh
  ├── Reads canonical hooks/hooks.json
  ├── Translates tool names and arguments
  ├── Runs canonical hook scripts in hooks/dev-rules/ and hooks/quality-gate/
  └── Formats stdout to Antigravity decision / injection contracts
```

### Event Contracts

| Antigravity Event | Canonical Claude Hook | Translation & Behavior |
| :--- | :--- | :--- |
| **`PreToolUse`** | `PreToolUse` (`Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob`) | Maps `toolCall.name` and arguments to Claude tools. If any guard denies, outputs `{"decision":"deny","reason":"..."}`. Otherwise outputs `{"decision":"allow"}`. |
| **`PostToolUse`** | `PostToolUse` (`Bash`) | Maps `run_command` exit status. Runs `clear-after-commit.sh`, `issue-comment-reminder.sh`, and `push-after-commit-reminder.sh`. Returns `{}` and buffers notices in `.dev-rules/.agy-pending-notices`. |
| **`PostInvocation`** | N/A (deferred queue) | Runs immediately after tool execution. Drains buffered notices and injects them as `ephemeralMessage`. |
| **`SessionStart`** | `SessionStart` | Injects LAW 42 (unrelated work) into git repo sessions via `systemMessage`. |
| **`PreInvocation`** | `UserPromptSubmit` | Injects LAW 13 (spec-driven flow / mode announcement) via `ephemeralMessage` when no cycle mode is selected. |

### Tool Mappings

| Antigravity Tool (`toolCall.name`) | Claude Code Tool (`tool_name`) | Arguments Mapped |
| :--- | :--- | :--- |
| `run_command` | `Bash` | `.toolCall.args.CommandLine` -> `command` |
| `read_file` / `view_file` | `Read` | `.toolCall.args.Path` -> `file_path` |
| `write_file` | `Write` | `.toolCall.args.Path` -> `file_path`, `.toolCall.args.Content` -> `content` |
| `edit_file` / `replace_file_content` | `Edit` | `.toolCall.args.Path` -> `file_path`, `.Target` -> `old_string`, `.Replacement` -> `new_string` |
| `multi_replace_file_content` | `Edit` | `.TargetFile` -> `file_path`, joined chunks -> `old_string` / `new_string` |
| `grep_search` | `Grep` | `.SearchPath` -> `path`, `.Pattern` -> `glob` |
| `find_by_name` | `Glob` | `.SearchDirectory` -> `path`, `.Pattern` -> `glob` |

---

## Validation

Verify plugin integrity anytime using the Antigravity CLI validator:

```bash
agy plugin validate .
```
