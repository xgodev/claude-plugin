# Flow -- how every change is made

A group of `../rules.md` (the index -- read it first). LAW numbers are
global; the language leaves cite them. Each rule binds with no
time-pressure, authority, or sunk-cost exception.

## LAWs

1. **RED-first TDD.** Before touching production code, write the test that
   proves the bug or validates the feature. Run it. SEE it fail (RED) for
   the right reason. Only then write production code (GREEN). A test
   written after the fix, passing immediately, proves nothing -- it is
   forbidden. An existing failing test is not your RED unless YOU ran it
   and watched it fail for THIS reason. Applies to "trivial" fixes too. For a BUG you understand the problem from the
   spec and the user (brainstorming) and write the test from the INTENDED
   behavior -- you do NOT read the production code first, because anchoring on
   what the buggy code does contaminates the oracle (LAW 11). Read the
   implementation only after the test is RED. This flow is LAW 13.
2. **Docs always synced, same commit.** Any change to behavior, public API,
   structure, or version updates its docs (README, CHANGELOG, skill,
   inline contract) in the SAME commit. "Docs in a follow-up PR" is a
   defect even if a reviewer approves it -- a doc that lies about shipped
   behavior breaks the next reader.
3. **Verify before claiming done.** Run the verifying command and read its
   output before saying fixed/passing/complete. Confidence from reading
   the code is a hypothesis, not evidence. "I'm sure it passes" is not
   "I ran it and it passed". When verifying means launching a process
   (server, daemon, CLI), tear it down reliably afterwards by PID/port --
   killing the launcher (`go run`, a wrapper script, the parent shell)
   often leaves the spawned child alive, holding the port and breaking the
   next run, which then looks like a fresh bug.
10. **Fix tooling at the source repo, never the cache.** When a skill, plugin,
    or generated dependency is wrong, fix it in the cloned SOURCE repo (and
    contribute upstream), never in the ephemeral plugin cache -- a cache edit
    is overwritten on the next update and never becomes a real contribution.
    Locate the source first; the cache is read-only in practice.
13. **Spec-driven flow: understand before you encode.** Every change starts
    with `brainstorming` -- lock the problem and the intended behavior WITH the
    user before touching production code. Then the path forks. A **bug** goes
    brainstorming -> RED (write the failing test from the intended behavior,
    run it, see it fail) -> only THEN read the implementation and fix. A
    **feature/improvement** goes brainstorming -> `writing-plans` ->
    `executing-plans`, batched PER DELIVERY, never per plan unit: (1) write
    ALL the tests of the change, no build; (2) ONE run -- compile + run them,
    see them all fail (RED); (3) implement every unit, no build in between;
    (4) ONE run of the same targeted tests, see them pass (GREEN); (5) ONE
    commit at the end (a long plan may split into phases -- one commit per
    phase, still never per unit). A plan unit is not a build point or a
    commit point, even when the plan template lists a per-task test/commit
    step: on a compiled workspace every extra run costs minutes and tokens of
    build output, and every pushed commit a full CI build. Locally run only
    the change's targeted tests; the full suite stays in CI. "I'll
    just code it, it's small" is the failure mode this LAW stops -- no
    triviality exception, same as LAW 1; the brainstorm can be three sentences
    and the plan three bullets, but understanding must precede code. The plugin
    ships a hook that enforces the ORDER deterministically for the BUG flow:
    production code is read- AND edit-locked until a failing test exists
    (`.dev-rules/.red-first-unlocked`). Declaring the feature flow
    (`.dev-rules/.mode-feature`) lifts that lock -- red-first is the bug gate;
    features are governed by the plan (LAW), not by RED. A cycle-closing commit
    (`fix(`/`feat(`/`bugfix(`/`Fix #`/`Fixes #`) re-arms both -- one more
    reason the commit closes the delivery, not a unit. The gates prove
    order and existence, never quality -- a sound plan and a meaningful test
    stay your job (and the reviewer's).

## Known limitations

- This skill enforces order and ownership; it cannot judge whether a test
  asserts the right behavior. Pair it with the mechanical gate and with
  reviewer judgment on test semantics.
- Under extreme combined pressure an agent may still comply in letter
  (writes a trivially-passing test, syncs a one-line doc) while missing
  intent. The Red Flags target the letter; semantic adequacy of the test
  and the doc remains a review responsibility.
- It does not cover language- or tool-specific idioms by design (no Cargo,
  no Slint, no framework rules). Those belong in a language-specific skill,
  not here.
- The flow gates (LAW 13) prove a plan/test exists and that you unlocked in
  order; they cannot judge whether the plan is sound or the test asserts the
  right behavior. They also cannot tell a feature from a bug -- you declare the
  flow by creating `.dev-rules/.mode-feature` (feature) or going straight to
  RED (bug). Reviewer judgment still required.

## Rationalizations -- and the reality

Populated from real subagent output under combined time + sunk-cost +
authority + exhaustion pressure (RED phase). If you catch yourself forming
one of these, you are about to violate a rule. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "I read the code, I'm sure, no need to run it / see it fail" | Reading is a hypothesis. RED-first and verify-before-done require the run, not the conviction. Unverified confidence is how regressions ship. |
| "The bug report points right at the [suspect] code -- I'll go straight there and read it, I get it in 30 seconds" | Reading the production code first makes your test assert what the code DOES, not what it SHOULD do. Both baseline agents went "straight to the coupon branch" and derived the expected value from the code they had just read. Lock the intended behavior WITH the user, encode it as a failing test, and open the implementation only after RED. |
| "I traced it by hand and verified mentally, the fix is obviously correct -- a failing test is ceremony here" | Mental verification is not a RED (LAW 1), and the trace came from the suspect code, not the spec. A baseline agent shipped a fix having only "verified mentally" -- that is confidence, not evidence (LAW 3). |
| "Brainstorming/a plan is ceremony for something this small" | The smallest changes are where unexamined assumptions waste the most work. The brainstorm can be three sentences and the plan three bullets, but understanding the intended behavior WITH the user must precede code. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation. Each maps to the rule it breaks. If you think it, stop and do the rule instead.

- "I'll add the test after" / "this is too simple to test" -> LAW 1
  (RED-first TDD).
- "The existing test already covers it, re-running is enough" -> LAW 1
  (you did not see YOUR RED fail).
- "Docs/CHANGELOG can be a follow-up PR" / "I'll note it in the PR" ->
  LAW 2 (docs synced, same commit).
- "It probably passes" / "I'm confident, no need to run" -> LAW 3
  (verify before claiming done).
- "Let me go straight to the [buggy function/block] and see what it does" ->
  LAW 13 (both baseline agents said exactly this -- "go straight to the coupon
  branch"; diagnosing from the code first anchors your oracle on what the code
  DOES, not what it should do -- read the implementation only after the test is
  RED).
- "I traced/verified it mentally, the fix is obviously right, no failing test
  needed" -> LAW 13 + LAW 1 (a baseline agent shipped after "verify mentally
  before shipping"; a mental trace is not a RED and it came from the suspect
  code, not the intended behavior).
- "I'll just start coding, the brainstorm/plan is obvious" -> LAW 13 (every
  change starts with brainstorming; bug -> RED, feature -> writing-plans).
- "I'll compile/test/commit after this unit to be safe" -> LAW 13 (batch
  it: all tests -> one RED run -> all code -> one GREEN run -> one commit;
  a per-unit cycle on a compiled workspace burns hours and one CI build per
  pushed commit).
