# Quality Gate

The quality gate fails a change **only** when it worsens a metric (fmt, lint,
build, test, complexity, coverage) relative to a base ref -- pre-existing debt
never blocks, only regressions do.

**The gate itself is not in this repo.** It lives in
[`xgodev/quality-gate`](https://github.com/xgodev/quality-gate) and ships as
per-language Docker images on GHCR (`ghcr.io/xgodev/quality-gate/<lang>`). Its
contract, exit codes, metrics, tamper-resistance, and per-language details are
documented there (`docs/contract.md`, `docs/output-format.md`,
`docs/languages/<lang>.md`).

This plugin only **consumes** those images, in two places:

## 1. The `gate.md` skill (`skills/dev/engineering/gate.md`)

A leaf of the `dev` skill. When you ask to "run the quality gate" / "check
quality before PR", it:

1. Picks the per-language image by a root file-sentinel (`Cargo.toml` -> rust,
   `go.mod` -> go, ...).
2. Runs it: `docker run --rm -v "$PWD:/src" -w /src
   ghcr.io/xgodev/quality-gate/<lang>:latest --base <ref> --format json`
   (logs bind-mounted to a separate host dir, never into your repo).
3. Interprets the JSON verdict, reads the per-metric logs, and reports with
   file:line pointers -- and enforces the anti-bypass LAWs (never sets
   `QG_BYPASS_REASON`, never edits code/config to pass, never opens the PR).

## 2. The PR-gate hook (`hooks/quality-gate/pr-gate.sh`)

A PreToolUse hook that runs the same image before `gh pr create`. `git push`
is never gated (work-in-progress must stay cheap; CI is the hard gate).

A repo can turn this hook OFF per language with a versioned `.qg-hook.json` at
its root (`{"pr_gate": {"rust": false}}`, or `{"pr_gate": false}` for all) --
for when a local gate is too slow to run on every PR and CI already enforces
it. It is not a bypass (no `QG_BYPASS_REASON`, no audit log, no code touched);
anything but a literal `false` leaves the gate ON. See `docs/hooks.md`.

## Requirements & overrides

- **`docker`** installed with the daemon running. Both the skill and the hook
  **fail open** (allow, with a warning) when docker or the image is
  unavailable -- a missing runtime never bricks your git. They never fall back
  to running tools directly.
- Default tag `latest`, refreshed each run (`--pull=always`); set `QG_TAG` to a fixed version (e.g. `v1.2.0`) for reproducible verdicts, or override the whole image
  ref with `QG_IMAGE` (e.g. a locally built image while developing the gate).
- The base ref must be resolvable inside the container; the mounted `.git`
  carries the refs (in CI, `actions/checkout` with `fetch-depth: 0`).

## Changing the gate

Adding a language, a metric, a Dockerfile, or a ruleset is work in
`xgodev/quality-gate` -- open an issue there. From this repo we consume the
images; we do not edit the gate.
