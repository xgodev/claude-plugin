---
name: skill-rules
description: Use when authoring or editing any Claude skill -- a SKILL.md or a script it ships -- before writing, to keep the skill portable across every developer and machine
---

# skill-rules -- Portable, Cross-Dev Skills

Rules every Claude skill must satisfy to work for ANY developer on ANY
machine. A skill is committed and shared; anything tied to one person's
environment breaks **silently** for everyone else -- it keeps working for
the author, so the defect hides until another machine runs it. Apply BEFORE
writing, the way `dev-rules` does for code: same discipline, scoped to skill
authoring.

This is a discipline skill, not a passive reference. The LAW below has no
"it works on my machine" exception.

## LAW 1 -- Portable by construction (no environment-tied hardcoding)

A committed skill -- the SKILL.md text AND any script it ships -- must
contain NO value tied to the author's machine, account, or install. In any
runnable command or path, the following are forbidden:

- a home/user path: `/Users/<name>`, `/home/<name>`, an absolute home dir.
- an absolute path to ANOTHER repo (assuming where someone cloned it).
- a pinned plugin/cache version segment: `.../<plugin>/<x.y.z>/...`.
- any path or value that differs between developers or machines.

The NAME of a repo, tool, or org may appear in prose; an absolute path to it
must never appear in a command.

### Resolve instead of hardcode

| Need | Portable resolution |
|---|---|
| This repo's root | `git rev-parse --show-toplevel` |
| User home | `$HOME` -- never `/Users/<name>` |
| A plugin/cache file across versions | glob the variable segment and pick newest: `.../*/*/file ... \| sort -V \| tail -1` |
| A tunable, endpoint, or token | environment variable, documented |
| A value that truly varies per machine and cannot be derived (e.g. where a sibling repo is cloned) | **ask the developer once, save it to per-machine memory, reuse it thereafter** -- and if it is a repo, offer to `git clone <url>` (the git URL is constant: embed it in the skill) |

### Before publishing -- grep your own skill

```bash
grep -REn '/Users/[a-z]|/home/[a-z]|/[0-9]+\.[0-9]+\.[0-9]+/' skills/ \
  && echo "FIX: machine-tied hardcoding above" || echo "portable OK"
```

Any hit that is a real per-machine value: stop and resolve it before commit.

## Rationalizations -- and the reality

| Excuse | Reality |
|---|---|
| "It works on my machine, ship it" | "My machine" is the one environment a shared skill must NOT assume. Works-for-author equals broken-for-everyone-else, and silently. |
| "I'll parameterize it later" | The hardcoded path ships now and breaks the next developer now. Resolve it in the same edit, not a follow-up. |
| "The path is the same for everyone on the team" | Clone locations, home directories, and plugin versions differ per person and per machine. "Everyone" is an assumption, not a fact -- verify by asking what you actually depend on. |
| "Putting the rule or path in my global config makes it global" | A per-user config file is global to projects but LOCAL to one machine; it never reaches another developer. Shared means committed and distributed, not "in my home directory". |
| "Pinning the exact plugin version is more precise" | A pinned version is wrong on every machine running a different version. Glob the version segment and pick newest. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation:

- "I'll just type the full `/Users/...` path here." -> LAW 1; resolve via `$HOME` or `git rev-parse`.
- "I'll point straight at the other repo's absolute path." -> LAW 1; ask once + per-machine memory (offer the clone).
- "I'll pin `.../<plugin>/<x.y.z>/...`, it's what I have." -> LAW 1; glob the version and pick newest.
- "I'll drop the rule in my home config so it's everywhere." -> it reaches only THIS machine; put shared rules in a committed, distributed skill.

All mean: resolve via `$HOME` / `git rev-parse` / env / glob, or ask-once +
per-machine memory. Then re-run the grep above.

## Living Document

When a skill is found tied to one environment: (1) fix the skill now, (2)
add the missing rule or anti-pattern HERE in the same change, (3) commit the
skill with its docs. Write it down -- the same leak must not recur.
