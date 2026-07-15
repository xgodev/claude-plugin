# Rust -- language-specific discipline shapes

Rust-concrete forms of the language-agnostic LAWs in
`../engineering/rules.md` (read that first; the numbers below refer to it).
This leaf exists because rules.md is language-agnostic BY LAW -- the Rust
idioms live here, not there.

## unsafe (LAW 16 -- every safety escape carries its written invariant)

- Every `unsafe { ... }` block and `unsafe fn` carries a `// SAFETY:`
  comment stating the invariant that makes it sound -- what must hold, and
  why it holds HERE. Without it the proof obligation the compiler handed
  you is silently lost and the next maintainer cannot tell whether a
  change breaks it.
- **No exception for `unsafe impl Send` / `unsafe impl Sync`.** That is an
  unaudited thread-safety promise -- the most dangerous kind, and the
  easiest to write by reflex to silence the compiler. It moves a data race
  from compile error to production heisenbug. Write the invariant (which
  fields, why they are safe to share/move) or do not write the impl.
- A blanket `unsafe impl<T> Send for Wrapper<T>` promises safety for ANY
  `T` -- a defect on its face. Bound it (`T: Send`) or justify per-type.
- Smell: a crate with dozens of `unsafe` sites and a handful of `SAFETY:`
  comments has an unaudited core.

## Swallowed errors (LAW 18)

- `.ok()` and `let _ = ...` on a `Result` require an adjacent
  `// intentional: <reason>`. A bare discard is indistinguishable from a
  swallowed defect in an audit, so the bare form reads as one.
- An empty `if let Err(_) = ... {}` is the same discard wearing a match.
- Library/core crates never `eprintln!`/`println!` as error handling --
  return the typed error (`thiserror`-style), or emit structured
  `tracing`/`log` events; the binary edge decides presentation.

## Test shapes (LAWs 14, 15, 17)

- Fixtures: versioned in the repo or generated under `CARGO_TARGET_TMPDIR`
  / `tempfile` -- never a path under the developer's `$HOME`, never the
  dev's real config as input. Local-only data gates behind an explicit env
  var and skips loudly when absent.
- `assert!(x.is_ok())` with no assertion on the value proves the call
  didn't error and nothing else -- assert the value.
- A golden test that runs the implementation twice and compares the runs
  proves determinism, not correctness.
- `#[ignore]` on a currently-failing test silences a known regression --
  CI never runs it again. Known-failing tests go to an xfail list that
  FAILS the build the day they start passing.
- A fixed `thread::sleep` / `tokio::time::sleep` to "let the other
  task/thread finish" is a scheduled race (LAW 17). Use a real signal:
  `JoinHandle::join`/`.await`, a `Condvar`, a channel, `Notify`, or a
  bounded readiness poll with a deadline.

## clippy suppression (the threshold belongs to the repo config)

- Suppression is per-item (`#[allow(...)]` on the fn/impl) and carries a
  `// reason:`. A module/crate-wide `#![allow(...)]` erases today's
  warning AND pre-approves every future violation in the file.
- If the lint has a threshold in the repo's own `clippy.toml`, a blanket
  `#![allow]` of it silently defeats the team's configured limit -- the
  quality-gate hygiene scan fails this. If the limit is genuinely wrong,
  raise it in `clippy.toml`, visible in the diff.

## Red flags (first-person; stop and do the rule)

- "unsafe impl Send, the compiler is just being strict" -> write the
  SAFETY invariant or you have an unaudited thread-safety promise.
- ".ok() and keep going, that error can't really happen" -> the errors
  that "can't happen" are the ones that do; discard with a written reason
  or handle it.
- "#[ignore] it for now and file a ticket" -> ignore IS untracking; xfail
  list that alarms on pass, or fix it.
- "A short sleep makes the test stable" -> stable on this machine at this
  load; join/await/Notify with a deadline instead.
