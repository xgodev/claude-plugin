# Architecture -- what a service is made of

A group of `../rules.md` (the index -- read it first). LAW numbers are
global; the language leaves cite them. Each rule binds with no
time-pressure, authority, or sunk-cost exception.

## LAWs

Each language leaf says how these are written in that language.

8. **Local-runnable: no hard external dependency for dev.** Depend on a
   port (interface), pick the implementation by config, and ship an
   in-memory implementation so the service boots and runs with ZERO
   external infra in dev. Dev default = in-memory; production overrides to
   the real backend via env. The in-memory arm must wire nothing that
   dials the network (no eager ping that blocks boot). A service that
   can't start without a live DB/cache is a development-velocity defect.
9. **Port against the live source of truth, not notes.** When porting or
   reimplementing a contract (API rewrite, protocol reimpl, format mapping),
   hit the LIVE source FIRST and build the new shape side-by-side with the
   real response -- field presence, nullability, derivations, number formats.
   Research notes / docs are a complement, never a substitute. Every observed
   divergence becomes a fix + a TODO line, not a guess. A "derived" field
   (computed by the original, not stored upstream) must be re-derived by
   reading the original's formatter, not invented.
   **Corollary -- prove the reference actually answered before trusting it.**
   A missing/empty/error response from the live source is NOT a contract
   value. If the port-forward, gateway, or auth wasn't returning, an empty
   body is "no data", not "null". Before concluding `field == null` (or any
   shape), assert a known non-empty field in the SAME response (e.g. an id,
   a required flag) to prove the source responded; cross-check >= 2 records and
   the introspected type. Concluding from a silent/broken reference is the
   same guessing this LAW forbids -- it just hides behind a real-looking call.
12. **Concurrency is a premise, not an optimization.** Any system that
    processes independent work items (jobs, events, requests, files, URLs)
    is designed AND shipped concurrent from line one: bounded worker pool or
    async fan-out, parallel-safe units, no shared mutable state, idempotent
    effects. A hard-coded sequential loop over independent items is a design
    defect, not a simplification -- a serial architecture hard-codes an
    assumption every later component silently depends on, and retrofitting
    concurrency then is a rewrite, not a tune. "Low volume today" does not
    buy a serial default. The trap to refuse explicitly: building a
    "concurrency-ready" design and then defaulting the pool to 1 worker. A
    concurrent path that is not the default is never exercised, never
    tested, and rots until the day it is needed -- ship with a concurrent
    default (N > 1) so the tested path IS the concurrent path. Sequential
    execution is the exception and requires a stated, real constraint
    (ordering dependency, transactional invariant, upstream rate limit) --
    and even then it is bounded concurrency tuned DOWN to 1 on top of a
    parallel-safe design, never an architecture that assumes a single
    thread. Code that "would break if run concurrently" is not simpler; it
    is hiding defects (shared state, non-idempotent writes) that running
    concurrent from day one would have surfaced while the system was small.
19. **Platform before code.** The smallest codebase wins. A cross-cutting
    concern the platform already provides -- authn/authz, mTLS, TLS
    termination, retries, per-route timeouts, rate limiting, routing -- is configured
    there (service mesh, gateway, orchestrator), never re-implemented in the
    app. Preference order: platform, then a maintained library, then bespoke
    code. Every line the app owns is a line someone maintains. Before
    writing any such concern in code, propose the platform option to the
    user and let them decide; code it only on their explicit call.
20. **Three layers, dependencies point inward.** Interaction (handlers: HTTP,
    gRPC, events, CLI, MCP), business (entities, services, repository
    interfaces) and persistence -- every outbound adapter: datastores and
    clients of other services -- are separate units, separate
    packages/modules, never one feature package holding all three. Business
    does not know persistence exists: it calls interfaces and never imports
    a driver, a datastore, a client, or a transport type. Interaction
    converts its payload to an entity and calls business, never persistence.
21. **Nothing bound to a vendor.** Observability (logs, traces, metrics, APM),
    datastores, queues and clients are reached through a vendor-neutral
    abstraction; the concrete vendor is chosen by config at the edge.
    Swapping the APM or the database is config plus a new adapter, never an
    edit to a handler or a service.
22. **Every dependency is an interface; a contract lives alone.** Data access
    is a `Repository` interface owned by the domain, implemented by a
    `Datastore` in persistence. A service is an interface too. The contract
    -- the interface plus the errors it promises -- lives alone in its
    package; every implementation (in-process, HTTP,
    gRPC, MCP, a database) lives in its own package named by how it
    implements it -- never beside the contract. Whatever creates an
    implementation (constructor, factory, provider) hands back the contract
    type, never the concrete one. Callers import only the contract, so
    moving a service out of process is a new implementation plus wiring,
    never an edit to a caller. A remote implementation is a client in
    persistence (LAW 20), outside the domain.
23. **Inversion of control.** A unit never builds its own dependencies: it
    declares them in its constructor and a DI container (the composition
    root) wires the graph at startup. The entrypoint holds only wiring.
    Choosing an implementation (datastore, in-process service vs remote
    client) is a wiring decision driven by config (LAW 25), never an `if` in
    business code. No global or singleton reached from inside a unit.
24. **One responsibility, one file, one public method.** A handler exposes
    exactly one public operation; a service exposes exactly one (one use
    case). A repository is the exception: its responsibility is ONE entity's
    persistence, so it exposes several operations -- all about that entity,
    none about another. One datastore implements one repository. A second
    public operation on a handler or service means a second unit: new file,
    new type.
25. **Everything operable is configurable, by convention.** Every value an
    operator may need to change in production -- URLs, client timeouts,
    pool sizes, collection/topic names, which implementation is wired,
    feature toggles -- is a registered config key with a safe default
    declared next to the code that owns it, overridable per environment with
    no code change. Defaults run locally out of the box (LAW 8); production
    only overrides. No operational literal in code and no ad-hoc environment
    read: an unregistered knob is invisible to operators.
26. **Stateless processes.** An instance keeps nothing in memory or on local
    disk that must outlive a request. Sessions, shared caches and files live
    in a backing service, so any instance can die or be replicated at any
    time.
27. **Operable lifecycle.** Every service exposes liveness and readiness.
    Liveness never checks a downstream -- a dead dependency would restart
    every instance at once; readiness checks only the backing services the
    instance cannot serve without, each check bounded by a deadline. It
    shuts down gracefully: on SIGTERM it stops taking work, drains in-flight
    requests and messages within a deadline, then closes its connections.
28. **Contract first.** Every interface the service exposes (HTTP, gRPC,
    event, MCP) has a versioned, machine-readable contract in the repo
    (OpenAPI, proto, AsyncAPI/JSON Schema), written before the handler, and
    the server and its clients are tested against it. A breaking change is a
    new version, never an in-place edit.

## Rationalizations -- and the reality

Populated from real subagent output under combined time + sunk-cost +
authority + exhaustion pressure (RED phase). If you catch yourself forming
one of these, you are about to violate a rule. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "DDD / clean architecture is too much for this small thing" / "the domain can import this client, it's just convenience" | The cost of layering when it is small is tiny; the cost of pulling apart a domain that imported an HTTP client three months later is huge. One inward arrow is how the boundary dies (LAW 20). |
| "Concurrency now is premature optimization / speculation; volume today buys nothing measurable" | Concurrency is not an optimization, it is the execution model (LAW 12). A serial architecture hard-codes an assumption every later component depends on; undoing it is a rewrite. Design parallel-safe now and ship concurrent now; tune N, never retrofit the model. |
| "I'll make it concurrency-READY but default to 1 worker; raising it later is a config change, not a redesign" | The path that is not the default is the path that is never run, never tested, and rots. A pool defaulted to 1 is a serial system wearing a config costume. Ship N > 1 so the exercised path IS the concurrent path; tune DOWN to 1 only for a stated, real constraint. |
| "Concurrency adds untested failure modes (races, interleaving); sequential is safer" | Those failure modes already exist as latent defects -- shared mutable state, non-idempotent writes -- merely hidden by serial luck. Running concurrent from day one surfaces them while the system is small and cheap to fix; serial-by-default ships them. |
| "One package per feature (domain + adapter + handler + wiring) keeps it simple; the use case already depends on interfaces" | A baseline agent shipped exactly this. Interfaces inside one package are not layers: the next change edits the adapter and the handler in the same unit, and the package imports the driver and the transport (LAW 20). Separate units per layer. |
| "Returning the concrete type is idiomatic / simpler" | The caller now names the implementation, so swapping it (another datastore, a remote client) edits every caller (LAW 22). Hand back the contract. |
| "One repository can serve both collections, it's the same feature" | Two entities, two responsibilities, two repositories (LAW 24). A repository that grows a second entity becomes the god file. |
| "I'll read the env var here and hardcode the timeout; swap in the real config loader later" | Both baseline agents did this. The literal ships; operators cannot see or change it (LAW 25). Register the key with its default now, next to its owner. |
| "Copy the service over unchanged, implementation beside its interface" | The day it goes remote, the implementation's package is also the contract's package and every caller is coupled to it (LAW 22). Contract alone; each implementation in its own package. |
| "Validating the token / retrying in code is safer than trusting the mesh" | Two layers doing the same job disagree on the edge cases and double the retries (LAW 19). Configure it on the platform; code only what the platform cannot do. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation. Each maps to the rule it breaks. If you think it, stop and do the rule instead.

- "A simple for-loop over the items is enough for now" / "single-threaded
  is simpler to reason about" -> LAW 12 (concurrency is a premise; a
  serial loop over independent items is a design defect).
- "I'll default the workers to 1 and we can raise it later" -> LAW 12
  (the non-default path is never exercised; ship concurrent by default).
- "Concurrency would be speculative at this volume" -> LAW 12 (it is the
  execution model, not a tuning knob; retrofitting it is a rewrite).
- "I'll write the auth/retry/TLS middleware myself" -> LAW 19 (propose the
  platform to the user first).
- "This feature package can hold the handler, the use case and the adapter"
  -> LAW 20 (three layers, separate units).
- "Import the vendor's tracer/client directly, it's what prod uses" -> LAW 21.
- "Put the implementation next to the interface" / "return the concrete
  type" -> LAW 22.
- "I'll construct the client inside the service" / "a package-level
  singleton is fine" -> LAW 23 (the container wires it).
- "Add a second public method to this handler/service" -> LAW 24 (new unit).
- "Hardcode it, nobody will change it" / "read the env var right here" ->
  LAW 25 (registered key, default next to the owner).
- "Keep it in a map in memory, it's only one instance" -> LAW 26.
- "Kill on SIGTERM, the orchestrator restarts it" -> LAW 27 (drain first).
- "Write the handler first, document the API after" -> LAW 28.
- "The domain can just call this driver/HTTP/env directly" / "clean
  architecture is over-engineering for this size" -> LAW 20.
