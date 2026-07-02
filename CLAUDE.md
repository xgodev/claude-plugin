# CLAUDE.md -- claude-plugin

This repo is the **all-in-one `claude-plugin`** by `xgodev` AND the single
`xgodev-plugins` marketplace (`.claude-plugin/marketplace.json`, one plugin
entry, source `./`). Everything that used to live in the retired repos'
plugin form -- `boost-claude` (`boost` skill), `quality-gate` (dispatcher +
gates + skills + pre-push hook), `dev-rules` (skill + RED-first hooks),
`skill-rules` (skill) -- now lives HERE, as one plugin, one version, one
install. It also wires the `playwright` MCP server.

These are hard rules, most of them learned the expensive way in the source
repos. Read them before changing anything.

## Hard rules (repo-wide)

- **Docs are ALWAYS updated in the same change. No exceptions.** Any change
  to code, structure, behavior, or version updates -- in the **same
  commit** -- every doc it affects: `README.md`, `CHANGELOG.md`, this
  `CLAUDE.md`, `docs/**`, per-language `<lang>/README.md`, the skills'
  `SKILL.md`s, and the `plugin.json` `description` if it no longer matches
  reality. A doc that lies is a defect, not a follow-up.
- **3-file version discipline.** A version change moves together, same
  commit: `.claude-plugin/plugin.json` `version`, the README `- Version:`
  line, and a `CHANGELOG.md` entry. ONE version for the whole bundle: any
  content change anywhere (a skill, a gate, a hook) bumps the single
  plugin version, or auto-update will not pick it up.
- **English only. Everywhere.** Docs, manifests, skills, code comments, and
  all runtime output. Public OSS -- no Portuguese anywhere.
- **Zero proprietary / internal references.** No internal company/product
  names, hosts, or repo URLs -- in code, docs, keywords, or examples.
  Before push: `grep -ri -E 'carrefour|bitbucket' . | grep -v '\.git/'`
  must be empty.
- **ASCII identifiers/commands; `--` not em-dash** in anything new.
- **Never guess Claude Code plugin specifics.** Verify against
  https://code.claude.com/docs (plugins / plugin-marketplaces /
  plugin-dependencies / hooks) before asserting.
- **Names are contract.** The plugin name `claude-plugin` and the
  marketplace name `xgodev-plugins` do not change without a documented
  migration (README + CHANGELOG + `renames` map in `marketplace.json`).
  The former plugin names (`golang-boost`, `quality-gate`, `dev-rules`,
  `skill-rules`) are mapped to `claude-plugin` in `renames` -- do not
  remove those entries; they migrate old installs.
- **Single plugin, single manifest.** Do NOT reintroduce per-area
  `plugin.json`s, per-area marketplaces, or `dependencies` between the
  bundled areas. Everything ships together.
- **Hooks live in `hooks/hooks.json` ONLY (auto-discovered).** Never also
  declare `"hooks"` in `plugin.json` -- the manifest key is only for
  ADDITIONAL non-standard files, and double registration breaks the whole
  plugin ("Duplicate hooks file detected", quality-gate 0.3.1 incident).
  `hooks/hooks.json` is the MERGE of the QG pre-push hook and the
  dev-rules hooks; when editing, keep all entries and run
  `hooks/test/hooks_json_test.sh`.
- **Editing/authoring any `SKILL.md` is gated** on the writing-skills
  workflow (subagent baseline BEFORE writing). The `skill-rules` skill in
  this very repo defines the portability law every skill here must obey
  (no `/Users/<name>`, no absolute paths to other repos, no pinned
  versions) -- run its pre-publish grep against `skills/` before commit.

## Area rules

### boost skill (`skills/boost/`)

- Skills cite boost as a Go import path (`github.com/xgodev/boost/...`),
  never as a file path of this repo.
- Sync with `xgodev/boost` is manual and mandatory: a component change
  there requires updating the matching
  `skills/boost/references/<group>/<name>.md` here (+ index line in
  `skills/boost/SKILL.md` for a new component), with a version bump.
- Run `python3 scripts/verify_references.py` after editing any reference
  file -- every `references/*.md` pointer must resolve.

### Quality Gate (`qg`, `<lang>/`, `tests/`, `hooks/pre-push-gate.sh`)

- **Self-contained -- no runtime clone/pull/cache.** The skill invokes the
  dispatcher at `${CLAUDE_PLUGIN_ROOT}/qg` (override only via `QG_PATH`
  for local development). Never reintroduce a `~/.<x>` clone + `git pull`
  cache.
- **Tamper-resistance is law.** The gate ships and enforces its own
  rulesets (`<lang>/rules/`); project quality configs are ignored by
  default. The only override is the `QG_RULESET_DIR` env var supplied by
  whoever RUNS the gate -- never read from a project file.
- **fmt/lint/complexity measure SOURCE, not generated output** (canonical
  QG-owned ignore list, never the project's ignore files).
- **The project's declared toolchain/build-system is authoritative.** If it
  cannot be honored exactly, that is tool-error exit 2 -- never silently
  substitute (no npm for a `yarn.lock`, no mvn for Gradle).
- **Every "tool missing" error teaches how to install it** (Linux + macOS
  commands + consequence).
- The full contract lives in `docs/contract.md`; adding a language follows
  the `add-quality-gate` skill and updates `docs/languages/<lang>.md` +
  `<lang>/README.md` in the same change. Test suite: `tests/*.bats`.

### dev-rules (`skills/dev-rules/`, `hooks/red-first-guard.sh` et al.)

- The hooks make RED-first deterministic: production edits blocked until a
  failing test exists (sentinels under `<project>/.dev-rules/`). Behavior
  and per-repo opt-out are documented in `docs/dev-rules.md` -- keep code
  and doc in lockstep.
- Hook changes require running `hooks/test/*.sh` (all green) before commit.

### skill-rules (`skills/skill-rules/`)

- The discipline skill itself: keep the rationalizations table and red
  flags populated from real failures; description stays verbatim English
  (it is the routing signal -- never paraphrase or summarize workflow in
  it).

## Common mistakes

- Bumping content without bumping the single plugin version (auto-update
  silently stops).
- Declaring `hooks` in `plugin.json` (breaks the whole plugin).
- Reintroducing per-area plugins/marketplaces or cross-marketplace
  dependencies -- retired in 1.0.0; the `renames` map replaced them.
- Putting skills in `.claude/skills/` (project-local, not distributed);
  plugin skills live in `skills/<name>/SKILL.md`.
- Any Portuguese string (run a language sweep before push).
- Touching `docs/quality-gate.md` links without re-checking relative paths
  (that file lives in `docs/`, so gate dirs are `../<lang>/`).
