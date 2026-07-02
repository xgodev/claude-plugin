# skill-rules

A single, **language-agnostic skill-authoring discipline** Claude Code
plugin. It encodes one rule that every Claude skill must satisfy: be
**portable across every developer and machine**. A skill is committed and
shared, so anything tied to one person's environment -- a home path, an
absolute path to another repo, a pinned plugin version -- breaks **silently**
for everyone else.

It is the companion to [`xgodev/dev-rules`](https://github.com/xgodev/dev-rules):
`dev-rules` governs how code is written; `skill-rules` governs how the skills
themselves are authored. Apply it **before** writing or editing a skill.

It is a **discipline-enforcing** skill: rigid, concise, applied before
writing -- not a passive reference skimmed after the fact.

## Install

`skill-rules` ships as part of the all-in-one `claude-plugin` -- see the
[repo README](../README.md) for install and update instructions.

## What it provides

- **LAW 1 -- Portable by construction.** No environment-tied hardcoding in a
  committed skill (SKILL.md or its scripts): no `/Users/<name>` or
  `/home/<name>`, no absolute path to another repo, no pinned plugin version.
- **Resolution table** -- how to resolve each need portably: `$HOME`,
  `git rev-parse --show-toplevel`, environment variables, version globs, or
  ask-once plus per-machine memory (with an offered `git clone`).
- **A pre-publish grep** that flags machine-tied hardcoding before commit.
- **Rationalizations** and **Red Flags** populated from real cross-dev
  failures, so the skill resists the "it works on my machine" shortcut.

## Relationship to the other skills

`skill-rules` is the meta-discipline of the bundle: `dev-rules` governs how
code is written, `quality-gate` catches mechanical regressions, and
`skill-rules` governs how the skills themselves are authored so they stay
portable across every developer and machine.
