# Testing -- the test stays honest

A group of `../rules.md` (the index -- read it first). LAW numbers are
global; the language leaves cite them. Each rule binds with no
time-pressure, authority, or sunk-cost exception.

## LAWs

5. **No skipped tests to go green.** Never skip/ignore/xfail/comment-out a
   test, lower a threshold, or pass `--no-verify` to make a gate green.
   Root-cause it or escalate with the real reason -- never disguise red as
   green. A skipped test is dead documentation, not a passing test.
11. **The test is the oracle -- never edit it to match the bug.** A failing
    test is a finding, not an obstacle. NEVER change a test's expected value,
    assertion, input, or tolerance so it passes against output you have not
    proven correct -- that turns a loud, true failure into a silent lie signed
    with your name, and hiding the error is the whole crime. "The expectation
    looks stale, just align `want` to what the code returns" is the exact move
    this forbids: matching the assertion to the OUTPUT hides the defect the
    test caught. The one discriminator: am I changing the test to match the
    SPEC, or to match the OUTPUT? You MAY change a test only when you can prove
    the new expectation is the intended behavior from a source of truth (spec,
    contract, the owner, a re-derivation) -- and that is a behavior change with
    its own RED (LAW 1), not a quick green. Editing `want`, loosening `==` to
    `>=`, deleting an assert, widening a tolerance, or narrowing the input
    until it passes are all the same forbidden act. Disabling instead of
    editing ("skip/xfail/quarantine just to unblock") is the same crime under
    LAW 5. No deadline, incident, or waiting room changes this -- an honest red
    beats a green that ships the defect.
14. **Tests are machine-independent.** A test must be reproducible on any
    machine. A hardcoded machine path (`/Users/<name>/...`, `/home/<name>/...`,
    `C:\Users\...`, `~/Library/...`, `%APPDATA%\...`) is a hard fail. Worse:
    a test that reads the developer's REAL config/data as a fixture (a live
    file under `$HOME`) changes result when the user edits unrelated things
    and passes only on the author's box. Fixtures are either versioned in
    the repo or generated in a temp dir (`mktemp`, `t.TempDir()`,
    `tempfile`). If a test genuinely needs local
    data, gate it behind an explicit env var and SKIP LOUDLY when absent --
    never pass silently.
15. **A test loosened to stay green is a lie.** The production fix must make
    the UNCHANGED test pass (extends LAW 11). The loosening shapes, all
    forbidden: a tolerance/epsilon widened ("generous", "robust") until a
    wrong result fits inside the window; a success-only assert with no
    assertion on the VALUE (proves the call didn't error, proves nothing
    about behavior); a "golden"/regression test that compares the
    implementation AGAINST ITSELF (two runs, assert they match -- proves
    only determinism, passes even if behavior is completely wrong);
    `ignore`/`skip` on a test that currently fails (silences a known
    regression). Known-failing tests go to an **xfail list that fails the
    build the day they start passing** -- so the fix is noticed -- never to
    `ignore`. Any tolerance change in a test diff is a review item.
17. **sleep() is never synchronisation -- wait on the condition.** In tests
    AND in production. A fixed `sleep(N)` to "let X finish" / "settle" /
    "prevent a race" is a bet on timing, not a guarantee: too short on a
    loaded CI, wasted time on a fast box, and it turns a deterministic
    dependency into a probabilistic one. There is almost always a real
    signal: a condvar, a join/waitpid, an epoch counter, a readiness check.
    The right shape is `wait_until(condition, deadline)`; a bounded poll
    with a deadline is acceptable; an unconditional fixed sleep is not. A
    magic duration "that reliably works on the machines we tested" is the
    same defect with tuning.

## Rationalizations -- and the reality

Populated from real subagent output under combined time + sunk-cost +
authority + exhaustion pressure (RED phase). If you catch yourself forming
one of these, you are about to violate a rule. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "The test expectation looks stale / the author left, just update `want` to what the code returns and unblock us" | Changing the assertion to match the OUTPUT asserts the output is correct -- a thing you have NOT proven. That is not fixing a stale test, it is signing off on the bug. Change a test only to match the SPEC (with proof + its own RED), never to match what the code happens to emit. |
| "Editing the assertion is risky, so I'll just `t.Skip`/quarantine it to unblock the unrelated hotfix" | Reaching for skip under incident pressure is still disabling the oracle (LAW 5). A quarantined test is not green, it is silenced. Root-cause or escalate with the real reason; do not trade an assertion edit for a disable. |
| "It passes on my machine, the path/config is right there" | Green on the author's box and red (or vacuously skipped) everywhere else protects nothing (LAW 14). Version the fixture or generate it in a temp dir; a test reading your real `$HOME` config asserts your laptop, not the code. |
| "I'll widen the tolerance a bit so it's robust / less flaky" | "Robust" here means "wide enough that a wrong result passes" (LAW 15). If the value is genuinely nondeterministic, assert the invariant that IS deterministic; do not grow the window until the bug fits. |
| "It didn't error, that's what matters" | Not-erroring is not behavior (LAW 15). A success-only assert with no expected VALUE passes for a function that returns garbage successfully. |
| "This test fails for a known reason, ignore it for now and track it" | `ignore` IS untracking (LAW 15, LAW 5): CI never runs it again and the regression is ratified. Put it on the xfail list that fails the build when it starts passing. |
| "A short sleep here makes the test stable" | It makes the test stable on THIS machine at THIS load (LAW 17). Wait on the condition with a deadline; a sleep that "works" is a race you scheduled to lose later, slower. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation. Each maps to the rule it breaks. If you think it, stop and do the rule instead.

- "Skip/ignore this one test and file a ticket" / "lower the threshold
  for now" -> LAW 5 (no skipped tests to go green).
- "Just align the expected value to what the code returns" / "loosen the
  assert / widen the tolerance so it passes" -> LAW 11 (the test is the
  oracle; match the spec, never the output).
- "The fixture is right there in my home dir, I'll just point the test at
  it" -> LAW 14 (machine-independent tests; version it or generate it in a
  temp dir).
- "Widen the epsilon / assert success-only and move on / compare against
  a previous run" -> LAW 15 (a test loosened to stay green is a lie).
- "sleep 100ms so the other thread finishes first" -> LAW 17 (wait on the
  condition with a deadline, never on the clock).
