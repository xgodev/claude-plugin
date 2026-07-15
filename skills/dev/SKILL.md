---
name: dev
description: "Use when writing, editing, or refactoring code in any language (engineering discipline -- before writing, not after); any work with github.com/xgodev/boost or Go services built on it; Rust work (unsafe, clippy discipline, test shapes); UI/UX design done while coding a feature; checking code quality before opening a PR -- \"run quality gate\", \"run QG\", \"check quality\", \"validate before PR\", \"qa before push\"."
license: MIT
metadata:
  author: jpfaria
---

The dev door. Read the row that matches, then the leaf it points to.
Paths are relative to this directory (`skills/dev/`).

| Context | Leaf |
|---|---|
| Writing, editing, or refactoring ANY code -- discipline, RED-first TDD, ownership, docs-synced commits | `engineering/rules.md` |
| Quality gate before a PR ("run QG", "check quality", "validate before PR") | `engineering/gate.md` |
| Go code -- language discipline (errors, tests, //nolint, concurrency) AND github.com/xgodev/boost work | `golang/index.md` (the Go leaf; routes on to `golang/boost/` for the framework) |
| Rust code -- unsafe/SAFETY:, Send/Sync impls, clippy suppression, Rust test shapes | `rust/rules.md` |
| UI/UX design -- palettes, styles, typography, charts, per-framework patterns, heuristics, a11y, design systems | `../ux-ui/index.md` (the ux-ui skill owns the design catalog + references) |
