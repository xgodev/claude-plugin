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

## Quality (LAW 40)

- Unsized input is read in chunks: `BufReader` + `read`/`lines`,
  `std::io::copy`, `memmap2` for random access. `std::fs::read`,
  `read_to_end`, `read_to_string` and `collect::<Vec<_>>()` over a stream
  only on input with a checked, small upper bound (CWE-770).
- Media is decoded packet by packet into a reused buffer (`symphonia`
  `next_packet` + `decode`), never into one `Vec` per file. A derived copy
  (resampled, transcoded) is written once to a file and memory-mapped.
- A real-time callback never touches I/O, locks or the allocator: a
  reader thread fills a lock-free ring (`rtrb`) ahead of the callback.
  Preloading the whole file is not the real-time-safe answer.
- Resources are released by ownership (RAII); a handle is never kept in a
  `static` without a release path.
- Every network call has a timeout (`reqwest` `.timeout()`,
  `tokio::time::timeout`) (CWE-1088).
- Arithmetic on sizes, indices and samples is `checked_*`/`saturating_*`,
  conversions are `try_from`, never a silent `as` truncation (CWE-190,
  CWE-197).

## Crate layout -- fast incremental builds from the first crate (One Responsibility Per File, LAW 40)

A crate is the unit of incremental compilation and of build parallelism:
editing one `.rs` file recompiles its whole crate and relinks every crate
above it. The layout is set on day one; a split done later, under
pressure, is a refactor of every import.

- **Small crates, one area each** (`<app>-core-<area>`, `<app>-gui-<area>`).
  Pure logic with no UI or framework dependency lives in its own crates.
  A crate nearing ~5k hand-written lines is split along an area boundary
  in the change that grows it.
- **Generated code gets its own crate, with nothing hand-written in it.**
  `slint_build`, `tonic-build`/`prost-build`, `bindgen`, any `build.rs`
  codegen: the crate holds the codegen source (`.slint`, `.proto`,
  headers), the `build.rs`, and a `lib.rs` that only includes the output
  (`slint::include_modules!()`, `tonic::include_proto!`). Adapters,
  mapping and callbacks live in another crate that depends on it. Editing
  Rust then never recompiles generated code, and editing the codegen
  source never recompiles the logic.
  - Slint: one UI crate per independent window, so editing one window's
    `.slint` does not regenerate the whole app.
  - Test-only UI harnesses live in their own crate, used as a
    dev-dependency -- never compiled into the production UI crate.
  - Slint's translation domain is the `CARGO_PKG_NAME` of the crate that
    compiles the `.slint` (read when `build.rs` runs). Moving `.slint`
    files to another crate changes the domain, and the existing catalog
    (`<lang>/LC_MESSAGES/<old-crate>.po`) is silently no longer found.
    Set the old domain in the new `build.rs` before calling `slint_build`
    (`std::env::set_var("CARGO_PKG_NAME", "<old-crate>")`; edition 2024
    makes it `unsafe`, with a `// SAFETY:` that the build script has no
    other thread yet), and check one translated string after the move.
- **Thin binary crate.** The bin only wires the crates together.
- **Build scripts read paths at run time.** `build.rs` reads
  `CARGO_MANIFEST_DIR` with `std::env::var`, never `env!`; a
  build-dependency helper takes its paths from the caller. Under a shared
  target dir cargo reuses a compiled build script or build-dependency
  across clones, and `env!` keeps the path of the clone that compiled it.

### Build machine

- `sccache` as `rustc-wrapper` in `~/.cargo/config.toml`, its cache
  (`SCCACHE_DIR`, `SCCACHE_CACHE_SIZE`) on a disk with room for every
  clone.
- sccache does NOT share third-party crates across clones: the target
  dir's absolute path is part of the key. The sharing comes from one
  `target-dir` in `~/.cargo/config.toml` for every workspace.
- Gotcha of the shared target: a workspace crate gets the same metadata
  hash in every clone of the repo, so two clones building at once
  overwrite each other's `lib<crate>-<hash>.rlib` -- E0432/E0425 on
  symbols that exist. A clone that must build in parallel uses its own
  `CARGO_TARGET_DIR`. To recover, `cargo clean -p <broken-crate> -p
  <crate-using-it>`; touching the sources is not enough.
- One cargo build at a time per machine: a wrapper script takes a
  machine-wide lock around cargo, and an agent hook denies a bare
  `cargo build`/`test`/`check` so every build goes through it.
- Measure before and after a split: touch one leaf `.rs`, `time cargo
  build`, both numbers in the PR. A split without numbers is a guess.

### Review flags (block the change)

- A crate with a codegen `build.rs` that also holds hand-written modules.
- A crate past ~5k hand-written lines, or a change that pushes one past.
- Logic in the bin crate.
- `env!` for a path in `build.rs` or in a build-dependency.
- A test-only window or harness inside a production UI crate.

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
- "`decode_file` returns a `Vec<f32>`, I'll reuse it for the new player"
  -> LAW 40: a reused helper that holds the whole input is the defect,
  not the pattern; stream it.
- "One crate to start, we split later" -> later is when one edit costs
  minutes and the split touches every import; split by area now.
- "The adapter is tiny, it can sit next to `include_modules!`" -> then
  every adapter edit recompiles the whole generated window; it goes in
  its own crate.
- "sccache already caches the deps across clones" -> not across target
  dirs; one shared `target-dir`, a per-clone one only to build in
  parallel.
