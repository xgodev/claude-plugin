# Design -- check before you code

A group of `../rules.md` (the index -- read it first). LAW numbers are
global; the language leaves cite them. Each rule binds with no
time-pressure, authority, or sunk-cost exception.

## STOP -- Check Before You Code

Run this list before writing the first line. It is language-agnostic;
"type", "id", "module", "package", "file" mean the same in Go, Python, TypeScript,
Rust, shell, anything.

- **Data Ownership** -- Each fact is defined in its owner, read from
  there, never inferred or duplicated. Never derive a type, brand,
  category, or fee from string matching (`startsWith`, `contains`, prefix,
  regex on an id). If you are pattern-matching an identifier to decide
  behavior, the owning definition is missing -- create it.
- **Separation of Concerns** -- Business logic vs presentation vs config
  are separate. Visual settings, env reads, and I/O wiring never live
  inside a business module. Reading `process.env` / `os.environ` deep in
  core logic is a concern leak: take it as a parameter.
- **Zero Coupling** -- No references to specific concrete IDs/brands/cases
  in shared code. Adding a new case must not require editing unrelated
  files. A consumer must not know a producer's internals. If "add a
  provider" means "edit 3 functions", the design is wrong -- fix the
  design, not add the 4th branch.
- **Single Source of Truth** -- A value lives in exactly one place. A
  string/number in 2+ places -> extract a named constant. Zero literals in
  comparisons or branches -- compare against the constant. "It's just one
  literal" is how the second copy is born.
- **Naming** -- Intent-revealing. No encoded type prefixes leaking
  implementation. Consistent across the codebase. A name that needs a
  comment to explain it is the wrong name.
- **No Trash** -- No dead or commented-out code, no legacy aliases, no
  "keep it just in case", no workarounds left in. Renamed something? Update
  ALL references now. "Someone might still call it" -> find out (grep); an
  unknown caller is not a reason to keep dead code, it is a reason to
  search.
- **Impact Analysis** -- Before a change, list what depends on it: callers,
  build scripts, config, data files, public signature consumers, docs.
  Verify each. A signature change with unverified callers is a regression
  waiting to ship.
- **Safe Refactoring** -- One concern per commit. After changing a
  struct/signature, update ALL constructors and callers in the same
  change. Verify before commit -- do not mix a refactor with a feature.
- **One Responsibility Per File (small units, parallel-safe)** -- If you
  describe a file with "and", it does too much. Module entrypoints are
  re-exports only. A match/switch/if chain that grows with every new case
  belongs split per-case behind an interface. New concern -> new file, not
  a new branch in a god file. Files, functions, and classes stay small on
  purpose -- not for aesthetics, so multiple agents and developers can work
  on different units at once with minimal merge conflict. A god file is a
  serialization point. The public-method budget per unit is LAW 24.
- **Library before custom (do not reinvent the wheel)** -- Before writing
  N lines, search if a well-maintained library already solves the problem.
  If a battle-tested lib makes the code smaller, clearer, and removes a
  maintenance burden, use it -- regardless of language. Weigh: the
  ongoing cost of a tiny added dependency is almost always less than the
  cost of bespoke, untested, lookalike code. "We have time, let's build it
  ourselves" is rarely true and almost never cheaper.
- **Designed for testability** -- The unit you are writing must be
  testable without a live network, a real database, a wall clock, or a
  mounted filesystem. Pure functions where possible. Side effects pushed
  to the edges. Dependencies passed in (constructor/argument), not
  imported as globals/singletons inside the function. No hidden state. If
  you cannot write a test for it without spinning up infrastructure, the
  design is wrong, not the test.
- **Domain at the center (DDD, always)** -- Domain-Driven Design is the
  default architecture, not an option: the domain (entities, value
  objects, aggregates, domain services, repository **interfaces**) is
  pure and depends on **nothing concrete**. Dependencies point INWARD.
  The architecture LAWs 19-28 (`architecture.md`) make this concrete: platform first,
  three layers, no vendor binding, interfaces everywhere, IoC, one
  responsibility, configuration, statelessness, lifecycle, contracts.

## LAWs

38. **Every exported unit documents its contract.** Every package and every
    exported type, function and method carries a doc comment saying what it
    promises: what it does, its inputs and outputs (with units), the error
    kinds it returns (LAW 7), its side effects, and the invariants a caller
    must keep. A comment inside a body says WHY (a decision, a constraint, a
    workaround with its link), never WHAT the next line does. The doc is
    part of the contract and changes in the same commit (LAW 2). A stale doc
    is worse than none: the reader, human or AI agent, trusts it, and an
    agent often sees only the signature and its doc, not the body.
39. **Technical documentation lives in the repo, diagrams included, and
    moves with the code.** `docs/` holds the architecture (the C4 context
    and container views), a flowchart of each non-trivial flow, a sequence
    diagram of each cross-service interaction (request, event, async), the
    data model, and the decisions (ADRs: context, decision, consequences).
    Diagrams are text (Mermaid, rendered by the code host), never a binary
    image or an external board link that cannot be diffed or reviewed. A
    change that alters a flow, a contract, a dependency or the data model
    updates its diagram in the same commit (LAW 2); a diagram that disagrees
    with the code is a defect. The README says what the service is, how to
    run it locally with no infra (LAW 8), its config keys, and where the
    docs live.

## Rationalizations -- and the reality

Populated from real subagent output under combined time + sunk-cost +
authority + exhaustion pressure (RED phase). If you catch yourself forming
one of these, you are about to violate a rule. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "An unknown external caller might break, so keep the alias / commented code" | An unknown caller is a reason to grep, not to keep trash. Find the callers or confirm none; do not preserve dead code on a guess. |
| "It's just one literal / one duplicate, DRY can wait" | The second copy is born exactly here. One place now, before the third copy makes it expensive. |
| "Building it ourselves is faster than learning the lib" | "Faster" here means today, alone. The lib has tests, docs, maintenance; the bespoke copy has none of those. Adopt the lib, or write down a real reason it cannot be used. |
| "Adding a dependency is bloat / scope creep" | A small, well-maintained dep that removes N lines of bespoke logic is the opposite of bloat. Treat the choice as a trade-off (size, surface, maintenance), not a reflex. |
| "I'll add tests later, the design is fine" | Untestable design is a defect surfacing now. If you cannot test it without infra, the structure is wrong -- fix the structure, not the test plan. |
| "The code is self-documenting, skip comments" / "a name that needs a comment is the wrong name" | A baseline agent found the Naming line read as backing exactly this. Naming governs names; a contract doc says what no name can -- error kinds, side effects, partial failure, invariants (LAW 38). |
| "Docs and diagrams are a follow-up, nobody reads them anyway" / "no rule names diagrams, so the new flow needs none" | The next reader is an agent that codes against the doc and the diagram as written. A new flow gets its diagram, a changed flow its updated one, in the same commit (LAWs 2, 39). |
| "Splitting into more files is over-engineering for this size" | Small units are not for aesthetics; they are how multiple agents/devs work in parallel without stepping on each other. A god file is a serialization point. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation. Each maps to the rule it breaks. If you think it, stop and do the rule instead.

- "I'll just infer it from the name/prefix/id" -> Data Ownership.
- "Adding this case means editing those other files too, fine" -> Zero
  Coupling.
- "It's only one literal in the comparison" -> Single Source of Truth.
- "Leave the old alias / commented block just in case" -> No Trash.
- "I'll just code it, the lib is overkill" -> Library before custom.
- "I'll add the dependency once it grows" -> "once it grows" is a session
  that ends with bespoke code; choose now.
- "I'll write the test once I get it working" -> Testable design (and LAW
  1). If you cannot test it without infra, the design is wrong.
- "One big file is fine for now" -> Small units / parallel-safe. A god
  file is a merge-conflict serialization point.
- "The name says it all, no doc comment" -> LAW 38 (the contract: kinds,
  side effects, invariants).
- "I'll draw the diagram after the PR" / "the old diagram is close
  enough" -> LAW 39 (the diagram moves with the code).
