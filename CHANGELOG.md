# Changelog

## [1.18.0]

### Added

- **Per-project opt-out for the PR-gate hook (`.qg-hook.json`).** A repo can
  turn the `gh pr create` gate OFF for a given language with a versioned
  `.qg-hook.json` at its root: `{"pr_gate": {"rust": false}}` disables it for
  Rust only, `{"pr_gate": false}` for every language. Motivated by slow local
  gates (Rust) where CI already enforces the same gate. The check runs right
  after language detection, before docker is consulted, so a disabled language
  never pulls or runs the image. This is **not a bypass** -- it sets no
  `QG_BYPASS_REASON`, writes no audit-log entry, and touches no code, test, or
  ruleset; the CI hard gate is unchanged. Fail-safe toward enforcement: an
  absent file, invalid JSON, a missing key, or any value that is not exactly
  `false` leaves the gate ON. The `/gate` skill honors the same file (a
  disabled language no longer auto-offers to run before a PR).
  `hooks/test/pr_gate_test.sh` covers the matrix.

## [1.17.1]

### Fixed

- **Kafka adapter config namespace follows the upstream fix.** The adapter root
  was `.kafka_confluent`, whose literal underscore no env var could express
  (the loader splits on `_`), so those keys were file-only. `xgodev/boost`
  renamed it to `.confluent` (issue #48, fixed in `ba0cff2`), so
  `adapter-kafka.md` now documents `boost.bootstrap.function.adapter.confluent.*`
  and the `BOOST_BOOTSTRAP_FUNCTION_ADAPTER_CONFLUENT_*` overrides that now work.

## [1.17.0]

### Added

- **`QG_PLATFORM` escape hatch for single-arch gate images.** When the pulled
  image has no variant for the host arch, docker fails with `no matching
  manifest` and the gate never runs. Setting `QG_PLATFORM=linux/amd64` runs it
  under emulation (slower). Wired into the skill, the PR-gate hook and
  `verify-gate-integration.sh`, which now names that cause instead of reporting
  a generic tool error. The real fix is a multi-arch image in the gate repo.

- **`scripts/verify_config_roots.py` -- a gate against the defect class above.**
  It extracts the literal `boost.factory.*` config roots from a boost checkout
  (`BOOST_SRC=...`) and fails when the skill documents a namespace matching
  none of them. Namespace drift is invisible at runtime and survives every
  routing test, so it needed a mechanical check rather than discipline.
  `scripts/config_roots_allowlist.txt` records the namespaces a leaf mentions
  precisely to say they do NOT exist, each with its justification -- a checker
  that fails on correct docs is a checker somebody switches off. Scope is
  deliberately `boost.factory.*` only: `boost.bootstrap.*` and
  `boost.wrapper.*` roots are composed at runtime, and faking coverage there
  would produce the false positives that kill a gate.

### Fixed

- **Veracity sweep of the whole boost skill against `xgodev/boost` -- ~68
  defects corrected.** The skill had never been verified against the framework
  it documents; routing tests cannot catch a leaf that routes perfectly and
  then teaches a constructor that no longer exists. Five independent audits
  (one per family) checked every import path, signature, config key, default
  and behavioral claim against a boost checkout, and a second, separate agent
  per family re-verified each finding before applying the fix. Highlights:
  - **Config namespace drift, silent at runtime** -- the skill documented the
    friendly vendor name where boost declares the module name:
    `boost.factory.kafka` -> `.confluent`, `.ftp` -> `.jlaffaye`,
    `.gocloud.pubsub` -> `.gocloud`, `.golang.x.net.http2.server` ->
    `.http2.server`, plus `boost.factory.gcp.api`/`.gcp.grpc`, which are not
    roots at all (those keys live at `<service-root>.apiOptions`/`.grpcOptions`).
    Wrong keys and their `BOOST_*` env vars are ignored without error, so the
    service boots on defaults and nothing complains.
  - **The env-var rule itself was wrong**, which invalidated camelCase examples
    throughout: the koanf loader lowercases each `_`-separated segment and needs
    `__` to mark camelCase, so `BOOST_PRINT_CONFIG_MAXLENGTH` never overrode
    `maxLength` (correct form: `..._MAX__LENGTH`).
  - **Deadletter routing was documented inverted** -- `Internal` is the default
    deadletter class (allowlist `[]string{"internal"}`), not `NotValid`; there
    is one subject, not per-type topics; and the prescribed `errors.Wrap`
    recipe made the matcher never fire, because `Unwrap()` returns `previous`
    while `Wrap` stores the typed error in `cause`.
  - **`wrapper/cache.md` did not compile at all** -- wrong driver constructor,
    wrong `NewManager` signature, a TTL argument `Set` does not take, `Get`
    documented with two return values instead of three, and a
    `cache.ErrNotFound` symbol that does not exist.
  - **Nonexistent symbols** in examples and red flags: `multiserver.New`/
    `WithServer`/`Run`, `emitter.Finish`, `srv.GracefulStop`, `fxfact.New`,
    `conn.Close`, `config.Set(key, value)`, and `.Register` used as a method
    value where the plugin interface takes the value itself.
  - **`start.md`** claimed config getters return zero values before `Start`
    (they panic), that the log backend is config-selected (it is always
    zerolog), and that the banner and config dump are default behavior (both
    opt-in, default false).
  - **`fx/modules.md`** taught hand-rolling modules that boost already ships --
    34 of them, including the exact example the file wrote by hand.
  - `NotValid` maps to HTTP 400, not 422.
  What held up: every import path incl. version segments, the full
  observability coverage matrix, and `echo`/`zap`/`zerolog`/`logrus`/`nats`/
  `pubsub`/`graphql`/`redis`/`elasticsearch`/`cassandra`/`language`.
- **Proprietary name removed from the public repo.** A client product name was
  used as the example upstream in `factory/resty.md` and `factory/hystrix.md`,
  present since 1.0.0; replaced with neutral names. It remains in git history.
- **`factory/database.md` now routes category requests, not just product
  names.** The table listed 12 storage components as bare vendor names with
  no data model, so a request phrased as a category ("a document database",
  "an embedded key-value store") was unroutable. Measured with cold
  subagents navigating from the `dev` door with grep/glob disabled: before,
  a document-database request landed on Mongo purely from the agent's own
  product knowledge ("the tables do NOT let me identify which components
  are document-oriented"), and an embedded-key-value request produced a
  4-way tie (BuntDB/MemDB/BigCache/FreeCache) the agent itself called
  guessing. Added a "Data model / role" column plus an instruction to route
  by it; both cases now resolve from the table's own text. Product-name
  routing ("quero usar BuntDB") was already correct -- verified 4/4
  unchanged (BuntDB, Goka, Vault, FreeCache) -- and the root `index.md`
  verified 6/6, so neither was rewritten.

### Changed

- **BREAKING: the `renames` map was removed from `marketplace.json`.**
  The pre-1.0.0 plugin names (`golang-boost`, `quality-gate`,
  `dev-rules`, `skill-rules`) no longer migrate to `claude-plugin`. Any
  install still pinned to one of those names stops resolving and receives
  no further updates; recover with
  `/plugin install claude-plugin@xgodev`. Re-adding the map later does
  not restore those installs retroactively.
- `CLAUDE.md` external-dependency law rewritten: cross-marketplace is now
  the form for ALL external dependencies (not only official-marketplace
  ones), with the two rules learned here -- name every non-official
  marketplace in the README install section, and only pin a `version`
  when the upstream tags releases.
- **Gate image default tag is now `latest`, force-pulled every run.** The
  skill and PR-gate hook defaulted to `:v1`, which the gate repo does not
  publish yet (only `:latest`, on main pushes), so the pull silently failed
  and enforcement stayed off. Default is now `ghcr.io/xgodev/quality-gate/
  <lang>:latest` with `docker run --pull=always`, so a moving `latest` is
  refreshed each run instead of gating against a stale cached copy. Set
  `QG_TAG` to a fixed version for reproducible verdicts; gate developers
  testing a locally built `QG_IMAGE` set `QG_PULL=never`.
- `CLAUDE.md` boost rule now requires verifying a leaf's claims against the
  boost source (with the file:line in the commit message) and running the new
  namespace checker -- the 1.17.0 audit found ~68 defects that pointer checks
  and routing tests had passed over for months.

### Not done, on purpose

- **No dependency on external design/code-quality skills.** Depending on
  `code-craftsmanship` + `systems-architecture` was implemented, then reverted
  after measuring it: those two plugins carry 12 skills whose descriptions load
  in EVERY session, ~2,000 tokens, against the ~304 tokens this whole plugin
  costs today. A door row pointing at them was also dropped -- a cold subagent
  invoked `domain-driven-design` on a domain-modeling prompt with no row
  present, so the row would have been documentation for a problem that does not
  exist. Install them directly if you want them; nothing here depends on them.

## [1.16.1]

### Added

- **Integration verifier for the consumed gate image.**
  `scripts/verify-gate-integration.sh` pulls the pinned
  `ghcr.io/xgodev/quality-gate/<lang>:<tag>` image and runs the plugin's exact
  `docker run` invocation against a throwaway rust repo, asserting a real
  verdict -- failing loudly if the image is missing/unpullable or produces no
  verdict, so the integration cannot silently rot behind the skill/hook
  fail-open. `.github/workflows/gate-integration.yml` runs it on demand + a
  daily heartbeat. Surfaced two blockers, tracked in `xgodev/quality-gate#15`:
  no `:v1` tag is published yet (only `:latest`, on main pushes), and the GHCR
  package must be made public for unauthenticated consumers.

## [1.16.0]

### Changed

- **The quality gate is no longer bundled in this plugin.** It moved back
  out to `xgodev/quality-gate` and ships as per-language Docker images on
  GHCR (`ghcr.io/xgodev/quality-gate/<lang>`). This plugin now only
  CONSUMES those images:
  - `skills/dev/engineering/gate.md` picks the per-language image by a root
    file-sentinel and runs `docker run -v "$PWD:/src" -w /src
    ghcr.io/xgodev/quality-gate/<lang>:v1 --format json` (logs bind-mounted
    to a separate host dir, never into the project). All anti-bypass LAWs,
    the exit-code map, and JSON interpretation are unchanged.
  - `hooks/quality-gate/pr-gate.sh` runs the same image before
    `gh pr create`. `git push` is still never gated.
  - Both **fail open** when `docker`/the daemon/the image is unavailable (a
    missing runtime must never brick git); neither falls back to running
    tools directly. Pin with `QG_TAG` (default `v1`); override the ref with
    `QG_IMAGE`.

### Removed

- The bundled gate (`tools/quality-gate/`), the gate-describing docs
  (`docs/contract.md`, `docs/consume.md`, `docs/output-format.md`,
  `docs/languages/`), and the maintainer-only `add-quality-gate` skill --
  all now belong to `xgodev/quality-gate`. Gate internals (a language, a
  metric, a Dockerfile, a ruleset) are an issue in that repo, not a change
  here.

## [1.15.0]

### Changed

- **Rust quality gate is now diff-scoped (issue #17).** For a touched `.rs`
  file the gate measured every metric over the entire workspace, twice (PR
  head + baseline), with `--all-targets` -- tens of minutes on a large
  native-heavy workspace, coverage OOMing the linker, and untouched crates'
  platform-specific examples gating unrelated PRs. It now resolves the
  affected workspace packages (changed packages + their in-workspace
  reverse-dependents, via `cargo metadata`) and scopes every cargo metric to
  that set (`-p <pkg> ... --lib --bins --tests`; examples built only for
  touched packages; coverage instruments only affected packages). The
  baseline is measured on the same set intersected with the packages that
  exist on the base ref (an added package reads base = 0), and the measured
  scope enters the base-metrics cache key so full and narrow runs never
  contaminate each other. Full-workspace fallback on a root-level diff
  (`Cargo.lock`, root `Cargo.toml`, `rust-toolchain*`, `.cargo/config*`, root
  `build.rs`) or `--force-full` / `QG_FORCE_FULL=1`. New `rust/lib/scope.sh`;
  scope reported in text and JSON output.
- The three-way changed-file union was copied byte-for-byte into all eight
  gates; it now lives in a shared `tools/quality-gate/lib/changed-files.sh`
  (`qg_changed_files`) that every gate sources. No behavior change for the
  seven non-rust gates.

## [1.14.1]

### Fixed

- LAWs 14-18 passed their missing pressure tests (5 subagent scenarios
  with deadline+authority+sunk-cost pressure; 5/5 complied, no wording
  change needed). CLAUDE.md gate widened: ANY file under skills/ requires
  the writing-skills flow, not just SKILL.md (the 1.12.0 loophole).

## [1.14.0]

### Added

- **Go language leaf** (`skills/dev/golang/index.md`): Go-concrete shapes
  of the LAWs (errors/%w, t.TempDir fixtures, time.Sleep-is-not-sync,
  //nolint discipline, -race/errgroup) plus the route to `golang/boost/`.
  Chain: dev door -> golang/index.md -> golang/boost/index.md. Authored
  through the writing-skills flow: baseline subagents documented the gap
  (no Go leaf; boost factory depth unannounced), the leaf + routing fixes
  closed it, and re-run scenarios verified both paths.

### Fixed (full-plugin review, 4 parallel reviewers)

- **Dispatcher: aggregate JSON corrupted by a silent tool-error gate.** A
  gate exiting 2 before rendering emits no JSON; the N-language envelope
  concatenated the empty string and produced invalid JSON. Such gates now
  get a valid stub result. Covered by a new dispatcher.bats case.
- **Dispatcher: hygiene now also runs when NO language is detected** (a
  violation turns exit 3 into exit 1), matching the documented "every
  run". Covered by a new dispatcher.bats case.
- **Docs telling lies**: docs/golang-boost.md showed a nonexistent tree
  (skills/boost/SKILL.md) and a nonexistent fx/pluggable-datastore.md;
  docs/hooks.md + plugin.json called the PR gate "opt-in" (it is on by
  default, fails open, bypassed only via QG_BYPASS_REASON); README had a
  duplicate ux-ui bullet and a stale hook list; ux-ui/index.md pointed
  search.py at the wrong path base, omitted 3 live search domains
  (web/react/google-fonts), and misstated the --persist output dir;
  search.py's docstring invented a "prompt" domain and hid 3 real ones;
  gate.md rendered "bypassed" as plain green in one table and as a
  warning in another; rust/rules.md cited an unnumbered LAW.
- **ASCII sweep**: em-dash/ellipsis normalized to ASCII across all skill
  markdown (73 files) and design_system.py output.
- **Dead payload removed**: orphan ux-ui/data/{design,draft}.csv;
  orphan docs/skills/quality-gate.md and the stale relocation spec.
- **Regression guard**: hooks_json_test now fails if plugin.json ever
  declares a "hooks" key (double registration breaks the whole plugin).
- **Gaps**: web gate got its missing README; contract documents
  HACK(#N), exit-code authority over per-gate JSON, and the no-language
  hygiene path; kill-switch doc names the reminders it silences;
  remaining Portuguese comments in nodejs/python bats translated;
  plugin.json description now counts all three skills and Rust.

## [1.13.0]

### Changed

- **Coherent skill layout, language-first.** The boost docs moved from
  `skills/dev/golang/` (a language-named folder holding framework docs)
  to `skills/dev/golang/boost/` -- `golang/` is the language area,
  frameworks nest inside it, same pattern as `rust/`. The design content
  moved out of `skills/dev/design/` into the `ux-ui` skill that owns it
  (`skills/ux-ui/{index.md,references/,data/,scripts/}`); the old thin
  ux-ui pointer skill is gone -- `dev` now cross-references
  `../ux-ui/index.md` for design done mid-feature. The `dev` door
  description dropped its design-trigger lead (ux-ui owns those
  triggers), shrinking the always-on cost. No name changes to the plugin
  or marketplace; always-on skill count unchanged (dev, ux-ui,
  skill-rules).

## [1.12.1]

### Fixed

- **Rust idioms leaked into the language-agnostic LAWs.** 1.12.0 put
  `is_ok()`, `unsafe impl Send/Sync`, `.ok()`/`let _ =` and
  `CARGO_TARGET_TMPDIR` inside `engineering/rules.md`, which every code
  session loads regardless of language -- against that file's own law.
  LAWs 14-18 are now fully language-neutral, and the Rust-specific
  shapes moved to a new `skills/dev/rust/rules.md` leaf routed by the
  `dev` door (loaded only for Rust work; zero always-on cost). Rule
  persisted in CLAUDE.md.

## [1.12.0]

### Added

- **dev-rules LAWs 14-18** (issues #9 #10 #12 #13 #14): machine-independent
  tests (no home-dir paths, never the dev's real config as a fixture); a
  test loosened to stay green is a lie (tolerance widening, value-free
  is_ok(), self-comparing goldens, ignore-on-failure -> xfail list);
  every safety escape carries its written invariant (unsafe // SAFETY:,
  especially unsafe impl Send/Sync); sleep() is never synchronisation
  (wait on the condition with a deadline); no swallowed errors (discards
  carry a reason; low layers return errors, they don't print). Each with
  rationalization-table and red-flag entries.
- **Quality-gate hygiene scan** (issues #7 #8 #11 #15):
  `tools/quality-gate/hygiene/scan.sh`, run by the dispatcher at the
  target root on every run. Hard violations (exit 1): neutered CI test
  steps (|| true, continue-on-error, dispatch-only test workflows), dead
  debt-allowlist entries, TODO(#N) referencing a CLOSED issue, blanket
  suppression canceling a repo-configured lint threshold. Ubiquitous
  legacy signals (bare TODOs, unreasoned blanket allows, file-level noqa)
  are warnings. Findings on stderr only (JSON stays parseable);
  QG_HYGIENE=0 (runner env) disables. Specified in docs/contract.md;
  covered by tests/hygiene.bats (11 tests, in CI).

## [1.11.0]

### Fixed

- **red-first-guard: directory-scoped reads no longer bypass the RED
  gate** (issue #6). With file-shaped `production_globs` (e.g.
  `crates/**/src/**`), `grep -r crates/`, `rg crates/x/src/`, and
  `ls crates/x/src` all slipped through: a directory token is a prefix
  of the glob, never a match, and `ls` was not in the guard's read-command
  list at all. `detect.sh` now treats a directory that can CONTAIN
  glob-matching files as production, and `ls`/`find`/`tree` are gated
  reads. Non-production directories (docs/, tests/) still pass.

### Added

- **mode-prompt hook (UserPromptSubmit)**: while no mode is chosen for
  the cycle, every user prompt gets the LAW 13 instruction injected (ask
  bug vs feature; bug => failing test before reading production), so the
  gate engages at the START of a flow instead of at the first production
  token (issue #6). Silent once a sentinel exists and under the kill
  switches; never blocks.

## [1.10.3]

### Fixed

- **fmt count broke under CI color.** prettier and stylelint colorize
  their output when they detect a CI environment (GITHUB_ACTIONS), so
  the `[warn]` parsing counted 0 formatting issues there. The nodejs and
  web gates now invoke them with `NO_COLOR=1 FORCE_COLOR=0`.
- Two web e2e test names translated to English.

## [1.10.2]

### Fixed

- The go/rust "base metrics cached" tests created their repo without
  pinning `init.defaultBranch=main` and then gated against `--base main`
  -- red on any machine whose git defaults to `master` (CI). Pinned, and
  the assertion converted to a bash-3.2-safe grep.
- The nodejs `count_fmt` test now dumps the prettier log on failure so an
  environment-only red is diagnosable from the bats output.

## [1.10.1]

### Fixed

- **Two quality-gate tests asserted nothing and one asserted the wrong
  thing.** The pr-gate hook swallows all gate output on the allow path, so
  the two --base forwarding tests (which used a PASSING stub) could never
  see the forwarded argv -- they now use a failing stub and assert on the
  deny reason. The python missing-tool test asserted on "python", which is
  present at /usr/bin on Linux -- it now asserts on pytest. Root cause of
  the false local greens: under macOS bash 3.2 a failing `[[ ]]` does not
  trip bats' `set -e` detection (documented in the tests README; CI runs
  bash 5).
- **CI toolchain gaps**: install gocyclo (the go gate treats it as
  required, per contract) and pin prettier/eslint/c8 as npm globals so
  the nodejs suite does not depend on ad-hoc npx downloads.

## [1.10.0]

### Added

- **CI (GitHub Actions).** `.github/workflows/tests.yml` runs on every
  push and PR: manifest validation, the 3-file version discipline check,
  all hook unit tests, skill reference integrity, and the bats suites
  with CI-installable toolchains (dispatcher, PR-gate hook, python,
  nodejs, go).

### Changed

- **Test+coverage fusion for the python, nodejs, java, and kotlin
  gates.** Each gate now runs its test suite ONCE per side and extracts
  both the failure count and the coverage percentage from that single
  run (`measure_test_and_coverage`), as rust/go/swift already did --
  previously each side ran the full suite twice. Safe fallbacks keep the
  failure count correct when the coverage plugin is absent (pytest-cov /
  kover), and nodejs projects with a custom `package.json` test script
  keep the previous two-run behavior.

### Fixed

- Translated the remaining non-English code comments and test messages
  (go, python, java, web gate sources; go/java/nodejs bats suites) --
  the repo is English-only.
- Removed a stale non-English planning document from `docs/`.
- `tools/quality-gate/tests/README.md` no longer lists a nonexistent
  `contract.bats` and now documents which suites run in CI.

## [1.9.0]

### Added

- **Issue-comment reminder hook** (issue #5): after a `git push` on an
  issue branch (any branch containing `issue-N`), a PostToolUse(Bash)
  hook injects a reminder to `gh issue comment N` with the commit
  hash(es), files changed, and build/test result. Reminder only -- never
  blocks; silent off issue branches, outside git repos, and under the
  dev-rules kill switches. Registered in `hooks/hooks.json` with its own
  test in `hooks/test/`.

## [1.8.0]

### Fixed

- **Pure UI/UX tasks now route to the design content** (issue #4). The
  `dev` description buried its design clause behind boost/Go/gate
  triggers, so design-only tasks lost the skill-selection race to
  generic UI skills. Two changes: the design triggers now LEAD the `dev`
  description with concrete phrases (design/redesign a screen, fix a
  navbar/layout, choose palette/typography, polish a UI), and a thin
  `ux-ui` door skill (~85 always-on tokens) exposes the same
  `dev/design/` content under a design-named skill that competes head-on
  with UI-branded third-party skills.

## [1.7.0]

### Changed

- **All 7 remaining gates got the rust 1.6.0 treatment.** Baseline dirs
  are now keyed by project + base SHA in every language (go, python,
  nodejs, java, kotlin, swift, web) -- fixing the same cross-project /
  stale-base poisoning bug -- and base metrics are cached per
  (base SHA, ruleset), so re-runs against the same base only measure the
  PR side. Test+coverage fused into a single suite execution for **go**
  (`go test -coverprofile` yields both) and **swift** (the gate literally
  ran the same `swift test --enable-code-coverage` twice). Fusion for
  python/nodejs/java/kotlin is follow-up work -- their base-metrics cache
  already halves repeat runs.

## [1.6.0]

### Changed

- **The QG hook gates ONLY `gh pr create` -- `git push` is never gated.**
  The gate belongs to the PR moment (and CI); a per-push gate costs
  minutes on heavy projects. The hook was renamed
  `hooks/quality-gate/pr-gate.sh`, its push-exemption logic removed, and
  the bats suite rewritten (`tests/hook-pr.bats`).
- **Rust gate: test and coverage fused into ONE suite execution.**
  `cargo llvm-cov --ignore-run-fail` yields the failure count and the
  coverage percentage from a single run -- the separate `cargo test`
  execution was a full extra suite run per side. Applies to comparative
  (base and PR) and absolute modes.
- **Rust gate: base metrics cached per (base SHA, ruleset).** Base
  metrics are a pure function of the base commit; re-runs against the
  same base now measure only the PR side. `--refresh-baseline`
  invalidates.

### Fixed

- **Rust baseline dir was shared across projects and base SHAs**
  (`/tmp/qg-baseline-rust` with a prepared-once sentinel), silently
  reusing another project's or an older base's extraction -- wrong
  verdicts and pathological runtimes. The baseline dir is now keyed by
  project and base SHA, which also makes staleness detection automatic
  (docs/consume.md described a staleness behavior the code did not
  implement; now it does).

## [1.5.0]

### Changed

- **BREAKING (skill namespace): skills unified into two doors.** The
  plugin now ships `dev` -- one door skill routing to
  `engineering/rules.md` (the former dev-rules), `engineering/gate.md`
  (the former quality-gate flow), `golang/` (the former boost index +
  references), and `design/` (the former ux-ui catalog engine +
  methodology) -- and `skill-rules` (unchanged; skill authoring is a
  separate concern). Always-on context cost drops from 5 skill lines to
  2. All gate scripts, hooks, engine, data, and references are intact --
  only the routing layer changed. Former namespaces
  (`claude-plugin:boost`, `:quality-gate`, `:dev-rules`, `:ux-ui`) are
  gone; the natural-phrase triggers all live in the `dev` description.

## [1.4.4]

### Changed

- **main-folder guard prescribes the clone naming rule** in its deny
  messages: the agent creates the worktree itself
  (`git worktree add .solvers/<name> -b <name>`), named `issue-<n>` when
  the work has a related issue, or a session/task slug
  (`sess-<yyyymmdd>-<short-task>`) when there is none -- every session
  gets its own isolated folder. Contract covered by tests.

## [1.4.3]

### Fixed

- English-only compliance for the 1.2.0 additions: the shipped
  `ux-ui` SKILL.md body and `docs/ux-catalog.md` were in Portuguese;
  both are now English (same routing tables, flags, and paths). The
  catalog doc also dropped an internal-repo provenance mention, and
  CLAUDE.md no longer instructs maintaining the retired
  `ux-ui-mastery` fork.

## [1.4.2]

### Fixed

- README caught up with 1.2.0 reality: the retired `ux-ui-mastery`
  dependency no longer appears (the content ships in the `ux-ui` skill,
  now listed with its namespace, layout entry, and context-overhead
  row); the only dependency is `superpowers`.

## [1.4.1]

### Changed

- **main-folder and line-cap deny messages now question the dev** (same
  contract as the RED-first guard in 1.4.0): they state that an agent
  changing the main working tree is NOT RECOMMENDED, and instruct the
  agent to ASK THE USER -- recommended flow (.solvers/ clone / split the
  file) or dev-authorized disable (guard-specific config key, or the
  .dev-rules/.off / DEV_RULES_OFF=1 kill switches). Message contracts
  covered by tests.

## [1.4.0]

### Added

- **Kill switches for all dev-rules guards**: `DEV_RULES_OFF=1` in the
  environment disables gating for the whole session
  (`DEV_RULES_OFF=1 claude`), and a `.dev-rules/.off` sentinel disables
  it until removed (toggled any time; cycle-closing commits never clear
  it, unlike `.mode-feature`/`.red-first-unlocked`). Both act in
  `dr_enabled`, so the RED-first, main-folder, and line-cap guards all
  honor them.

### Changed

- **RED-first deny messages now question the dev** instead of letting
  the agent pick a flow on its own: ask the user whether it is a BUG
  (RED first), a FEATURE (`.mode-feature`), or whether to disable the
  gates (`.dev-rules/.off` / `DEV_RULES_OFF=1`). Message contract
  covered by tests.

## [1.3.0]

### Added

- **Two new dev-rules hooks** (issue #2), registered in
  `hooks/hooks.json` next to the RED-first guard, each with its own test
  in `hooks/test/`:
  - `main-folder-guard.sh` (opt-in via `"main_folder_guard": true` in
    `.dev-rules.json`): denies `Edit`/`Write` targeting the main working
    tree and bare mutating VCS commands there -- work happens in
    `.solvers/<task>/` clones. Keyed off the operation's TARGET, so a
    session rooted in the main folder can still drive the clone; reads,
    `git status/log/diff/fetch`, `worktree add`, and `.dev-rules/` /
    `.claude/` writes always pass.
  - `line-cap-guard.sh` (on by default): denies edits that GROW a source
    file already over its line cap, forcing a split first. Shrinking
    edits, new files, tests, and docs/config always pass. Configurable
    per repo: `line_caps` (per extension), `line_cap_default` (500),
    `line_cap_guard: false` to disable.
  Consumer projects carrying local copies of these hooks can delete them
  and rely on the plugin registration.

## [1.2.0]

### Added

- **`ux-ui` design skill** — a single door skill (same shape as `boost`): an index
  SKILL.md that routes by **catalog** (a BM25 search engine over palettes, styles,
  typography, charts, UX guidelines, icons + per-framework `--stack` patterns for
  17 stacks; from `ui-ux-pro-max`) and by **methodology** (19 short-named
  `references/*.md` leaves — heuristics, a11y, design-systems, visual, components,
  motion, states, mobile, desktop, cognitive, research, metrics, ethics, i18n,
  critique, figma, agentic, spatial, ambient — migrated from the `ux-ui-mastery`
  fork). Catalog data is queried by the engine, never loaded into context. See
  `docs/ux-catalog.md`.

### Changed

- **Absorbed the `ux-ui-mastery` dependency into the bundle.** Removed the
  `ux-ui-mastery` plugin entry from `.claude-plugin/marketplace.json` and the
  dependency from `.claude-plugin/plugin.json`; the design content now ships in the
  `ux-ui` skill. The `xgodev/ux-ui-mastery` fork repo is retired/archived.

## [1.1.9]

### Fixed

- A `.dev-rules/.mode-feature` sentinel was accidentally committed,
  which would disable the RED-first gate for every clone of this repo.
  Removed from the index; `.dev-rules/` is now gitignored (sentinels are
  per-machine runtime state, never repo content).

## [1.1.8]

### Fixed

- `red-first-guard.sh` never matched project-relative `production_globs`
  against the absolute paths Claude Code sends for Edit/Write, so a
  `.dev-rules.json` with explicit globs silently disabled the gate. The
  guard now strips the project prefix (and an isolated-workspace
  `.solvers/<name>/` prefix) before classifying the path.

## [1.1.7]

### Fixed

- The pre-push sweep instruction in CLAUDE.md embedded the very names it
  exists to keep out of a public repo; the rule is now stated
  generically (the concrete pattern lives outside the repo).

## [1.1.6]

### Changed

- README context-overhead numbers refreshed for the trimmed
  descriptions: plugin overhead is now ~370 tokens/session (+1.4%).
  Measured end-to-end, the 1.1.5 + ux-ui-mastery 3.0.1 trims cut 752
  tokens/session off a fully loaded setup (29,227 -> 28,475).

## [1.1.5]

### Changed

- **Skill descriptions trimmed to trigger-only lines** (`boost`,
  `quality-gate`) -- descriptions load into every session's context;
  workflow and prohibition text lives in the SKILL.md bodies (where it
  already was). Same routing triggers, fewer always-on tokens. The
  `ux-ui-mastery` fork got the same treatment for its 19 skills (3.0.1).

## [1.1.4]

### Added

- **Dependency on `ux-ui-mastery`** (Design Tribe Republic). Upstream
  `phazurlabs/ux-ui-mastery` ships a `plugin.json` that Claude Code
  rejects (`skills` entries point at `SKILL.md` files instead of skill
  directories, and custom paths lack the `./` prefix), which blocked the
  1.1.0 attempt. It is now served from the `xgodev/ux-ui-mastery` fork
  carrying exactly that manifest fix, listed in the `xgodev` marketplace
  with a GitHub source, and declared in `plugin.json` `dependencies` --
  auto-installs with `claude-plugin`. Switch the source back to upstream
  once the fix lands there.

## [1.1.3]

### Fixed

- **`superpowers` dependency resolves from `claude-plugins-official`.**
  Serving it from the `xgodev` marketplace (1.1.1) created a DUPLICATE
  plugin for everyone who already had
  `superpowers@claude-plugins-official` installed -- Claude Code treats
  the same plugin from two marketplaces as two plugins. The dependency
  is now the cross-marketplace form
  (`{"name": "superpowers", "marketplace": "claude-plugins-official"}`,
  allowlisted via `allowCrossMarketplaceDependenciesOn`); the official
  marketplace is preconfigured in Claude Code, so it still auto-installs
  with no extra step, and an existing install satisfies it.

## [1.1.2]

### Changed

- README describes current state only -- dropped a leftover historical
  aside in the context-overhead table. History lives here in the
  CHANGELOG, not in the README.

## [1.1.1]

### Added

- **Dependency on `superpowers`** (Jesse Vincent, `obra/superpowers`):
  core skills library (TDD, debugging, collaboration patterns). Listed in
  the `xgodev` marketplace with a GitHub source and declared in
  `plugin.json` `dependencies`, so it resolves same-marketplace and
  auto-installs with `claude-plugin` -- no extra
  `/plugin marketplace add`. Verified end-to-end with a local install.

### Removed

- **`ux-ui-mastery` dependency (added in 1.1.0) dropped for now.** Its
  upstream `plugin.json` (v3.0.0) is rejected by current Claude Code
  manifest validation (`commands` / `skills` fields), which made the
  whole `claude-plugin` install fail. Re-add once
  `phazurlabs/ux-ui-mastery` ships a valid manifest.

- **"Migrating from earlier layouts" README section.** The pre-1.0
  layouts (per-repo marketplaces, multi-plugin marketplace) had no real
  adoption, so the migration walkthrough was dead weight. The
  `renames` map in `marketplace.json` stays -- it still auto-migrates any
  old install transparently.

## [1.1.0]

### Changed

- **Marketplace name is `xgodev`.** Installs are `claude-plugin@xgodev`.
  The `xgodev-plugins` name introduced in 0.8.0 was never adopted in the
  wild, so no migration is needed; README install/update/auto-update
  instructions were updated.

- **Quality Gate bundle relocated to `tools/quality-gate/`.** The
  dispatcher `qg`, the eight per-language gate dirs (`go/`, `java/`,
  `kotlin/`, `nodejs/`, `python/`, `rust/`, `swift/`, `web/`) and the bats
  suite (`tests/`) moved from the repo root into
  `tools/quality-gate/`, leaving the root with only the plugin
  skeleton (`.claude-plugin/`, `skills/`, `hooks/`, `docs/`, `scripts/`).
  No gate behavior changed. All path references were updated in the same
  change: the pre-push hook, the `quality-gate` and
  `add-quality-gate` skills (`QG_PATH` still points at the quality-gate
  dir; its default is now `$CLAUDE_PLUGIN_ROOT/tools/quality-gate`),
  the test helpers, `docs/**`, per-language READMEs, `README.md`,
  `CONTRIBUTING.md`, and `CLAUDE.md`. CLI users: the dispatcher is now
  `<clone>/tools/quality-gate/qg`.

- **Hook scripts grouped by area.** The registry stays at
  `hooks/hooks.json` (standard auto-discovered path -- unchanged), but the
  scripts moved into per-area subdirectories:
  `hooks/quality-gate/pre-push-gate.sh` and
  `hooks/dev-rules/{red-first-guard.sh, clear-after-commit.sh, lib/}`.
  `hooks/test/` still covers all of them.
- **`add-quality-gate` is no longer shipped with the plugin.** It is a
  maintainer tool (adding a language to the gate is this repo's task, not
  something done in a consumer project), so it moved from `skills/` to
  the project-local `.claude/skills/add-quality-gate/`. End-user installs
  now receive four skills: `boost`, `quality-gate`, `dev-rules`,
  `skill-rules`. The `quality-gate` skill still names it on exit 3 -- the
  guidance ("open an issue / add the language in the gate repo") is
  unchanged.

### Added

- **Dependency on `ux-ui-mastery`** (Design Tribe Republic,
  `phazurlabs/ux-ui-mastery`). Declared in `plugin.json`
  `dependencies` with `marketplace: "ux-ui-mastery-marketplace"`;
  `marketplace.json` allowlists it via
  `allowCrossMarketplaceDependenciesOn`. Users add that marketplace
  first (`/plugin marketplace add phazurlabs/ux-ui-mastery`) and Claude
  Code auto-installs the dependency with `claude-plugin`.
- **"Context-window overhead" section in the README** with measured
  numbers: installing the plugin costs ~510 tokens per session (+1.9% over
  the Claude Code baseline), A/B-tested with `claude -p` on Claude Code
  2.1.199. Skill bodies, hooks, and the gate itself cost zero until used.

### Removed

- **`playwright` MCP server unbundled.** The plugin ships only xgodev's
  own capabilities; a third-party MCP server is not one of them. The
  `mcpServers` block was removed from `plugin.json`. If you used
  playwright through this plugin, add it to your own Claude Code config:
  `claude mcp add playwright -- npx -y @playwright/mcp@latest`.

### Fixed

- `docs/consume.md` and the per-language READMEs still instructed cloning
  the retired `xgodev/quality-gate` repo into a `~/.quality-gate` cache;
  they now point at this repo and the bundled gate path. A stale
  `~/.quality-gate` reinstall hint in the nodejs gate's tsconfig error
  message was updated too.

## [1.0.0]

### Changed

- **BREAKING: all-in-one plugin.** The four separate plugins were merged
  INTO `claude-plugin` itself: the `boost` skill set (from
  `xgodev/boost-claude`), the Quality Gate -- dispatcher `qg`, per-language
  gates, `quality-gate`/`add-quality-gate` skills, bats suite, opt-in
  pre-push hook (from `xgodev/quality-gate`) -- the `dev-rules` skill +
  RED-first enforcement hooks (from `xgodev/dev-rules`), and the
  `skill-rules` skill (from `xgodev/skill-rules`). One plugin, one version,
  one install; `dependencies` removed; `hooks/hooks.json` is the merge of
  the QG pre-push hook and the dev-rules hooks. Skills are now namespaced
  `claude-plugin:<skill>` (was `<plugin>:<skill>`). The marketplace lists
  only `claude-plugin` and maps the former plugin names to it via
  `renames` (auto-migration on Claude Code v2.1.193+; older versions:
  uninstall the four, install `claude-plugin`). Per-area user docs moved
  to `docs/golang-boost.md`, `docs/quality-gate.md`, `docs/dev-rules.md`,
  `docs/skill-rules.md`; the Quality Gate contract docs keep their
  `docs/` paths (`contract.md`, `languages/*`, `hooks.md`, ...). The
  source repos are retired (their pre-merge history stays there). Also
  ships the repo-level `LICENSE` (MIT) and a consolidated `CLAUDE.md`.

## [0.8.0]

### Changed

- **BREAKING (install path): single marketplace `xgodev-plugins`.** This
  repo's marketplace was renamed from `xgodev-claude-plugin` to
  `xgodev-plugins` and now lists every `xgodev` plugin directly:
  `golang-boost`, `quality-gate`, `dev-rules` and `skill-rules` via GitHub
  sources (`{ "source": "github", "repo": "xgodev/<repo>" }`, each shipped
  from its own repo), plus the umbrella `claude-plugin` (source `./`). The
  per-repo marketplaces (`xgodev-boost`, `xgodev-quality-gate`,
  `xgodev-dev-rules`, `xgodev-skill-rules`) are retired. `plugin.json`
  `dependencies` switched from the cross-marketplace object form to bare
  names (same-marketplace resolution), and
  `allowCrossMarketplaceDependenciesOn` was removed. Existing users must
  remove the old marketplaces and re-add this one -- see "Migrating from
  the per-repo marketplaces" in the README. README and CLAUDE.md rewritten
  for the new shape.

## [0.7.2]

### Changed

- **`golang-boost` moved to its own repo `xgodev/boost-claude`.** The
  `xgodev-boost` marketplace is now published from `xgodev/boost-claude`
  instead of `xgodev/boost` (the plugin was extracted so installing it no
  longer clones the whole framework). No JSON change was needed here: the
  cross-marketplace dependency resolves by marketplace name (`xgodev-boost`),
  which is unchanged. README links repointed to `xgodev/boost-claude`.

## [0.7.1]

### Fixed

- **`boost` dependency name corrected to `golang-boost`.** The `boost`
  dependency pointed at plugin name `boost`, but the plugin published in the
  `xgodev-boost` marketplace (repo `xgodev/boost`) is named `golang-boost`.
  Installing the umbrella therefore failed with
  `Dependency "boost@xgodev-boost" is not installed`. `plugin.json`
  `dependencies` now uses `{ "name": "golang-boost", "marketplace": "xgodev-boost" }`;
  README, `marketplace.json` description, and `CLAUDE.md` updated to match.

## [0.7.0]

### Added

- **`skill-rules` dependency.** Pulls `skill-rules@xgodev-skill-rules` via a
  cross-marketplace dependency, alongside `boost`, `quality-gate` and
  `dev-rules`. `skill-rules` is the skill-authoring companion to `dev-rules`:
  it requires every Claude skill to be portable across all developers and
  machines (no environment-tied hardcoding). `plugin.json` `dependencies`
  gains `{ "name": "skill-rules", "marketplace": "xgodev-skill-rules" }`, and
  `marketplace.json` `allowCrossMarketplaceDependenciesOn` gains
  `xgodev-skill-rules` so the dependency auto-installs.

## [0.6.0]

BREAKING -- marketplace rename + cross-marketplace dependencies.
Requires Claude Code v2.1.110+ (cross-marketplace deps support).

Note: 0.5.0 was pushed briefly with a decoupled shape (no dependencies)
and is superseded by this entry. Use 0.6.0+.

- Marketplace `name` renamed from `xgodev` to `xgodev-claude-plugin`
  (more specific identifier: a single owner can host multiple
  marketplaces; the generic `xgodev` ID collided with other `xgodev/*`
  marketplaces). Installed as `claude-plugin@xgodev-claude-plugin`.
- Dependencies migrated from the same-marketplace re-listing pattern
  to the canonical **cross-marketplace** form. `plugin.json`
  `dependencies` now uses the object shape
  `{ "name": "<plugin>", "marketplace": "xgodev-<plugin>" }` for
  `boost`, `quality-gate` and `dev-rules`, pointing at their standalone
  marketplaces (`xgodev-boost`, `xgodev-quality-gate`,
  `xgodev-dev-rules`). The previous re-listings of those three plugins
  under `plugins` in `marketplace.json` were removed (they would
  collide with the standalone marketplaces). Source of truth:
  https://code.claude.com/docs/en/plugin-dependencies
- `marketplace.json` declares
  `allowCrossMarketplaceDependenciesOn: ["xgodev-boost",
  "xgodev-quality-gate", "xgodev-dev-rules"]` so Claude Code is
  allowed to resolve and auto-install those dependencies on
  `claude-plugin` install.
- `CLAUDE.md`, `README.md` and `plugin.json` `description` synced with
  the umbrella + cross-marketplace shape in the same change.

## [0.4.0]

- Added `dev-rules` as a plugin dependency: declared in `plugin.json`
  `dependencies` and re-listed in `marketplace.json` (anonymous HTTPS clone
  of [`xgodev/dev-rules`](https://github.com/xgodev/dev-rules)). The umbrella
  now provides the macro language-agnostic engineering-discipline skill
  alongside `quality-gate` and `boost`. README + the stale `marketplace.json`
  self-description synced in the same change.

## [0.3.3]

- Removed the `## Skills` section from `README.md`: this plugin ships no
  skills of its own (umbrella). What capabilities you get is fully covered
  by the `## Dependencies` section; a Skills table listing `quality-gate`
  was misleading.

## [0.3.2]

- Synced `README.md` (it was not updated in the same change as 0.3.1 —
  the docs-always-synced rule was added then immediately violated): intro
  now matches the umbrella framing (bundles no skills; capabilities via
  dependencies); removed a Portuguese trigger example (`rodar QG`) —
  public OSS is English only.

## [0.3.1]

- Added `CLAUDE.md` codifying the repo's hard rules (docs always synced,
  3-file version discipline, English-only, zero internal refs, dependency
  pattern, plugin skills location, MCP wiring).
- Fixed the `plugin.json` `description`: it still described a bundled
  quality-gate skill; this is an umbrella plugin that bundles no skills and
  provides them via dependencies.
- Translated `CHANGELOG.md` to English (public OSS — English only).

## [0.3.0]

- `quality-gate` skill unbundled; now provided via a dependency on the
  `quality-gate` plugin (re-listed from github.com/xgodev/quality-gate in
  `marketplace.json` + declared in `dependencies` in `plugin.json`). The
  skill and the gate ship inside that depended plugin.
- `boost` dependency and the `playwright` MCP server kept.

## [0.2.0]

- `boost` plugin dependency (re-listed from github.com/xgodev/boost in
  `marketplace.json` + declared in `dependencies` in `plugin.json`).
- `playwright` MCP server (`@playwright/mcp`, stdio via npx) wired in
  `mcpServers`.

## [0.1.0]

- First public release.
