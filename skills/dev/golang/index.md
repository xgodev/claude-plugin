# Go -- language leaf

Go-concrete shapes of the language-agnostic LAWs in
`../engineering/rules.md` (read that first; numbers below refer to it),
plus the routes to Go frameworks. This file exists because rules.md is
language-agnostic BY LAW -- the Go idioms live here, not there.

## Routes

| Context | Reference |
|---|---|
| github.com/xgodev/boost -- the Go service framework (any boost import, boot/wiring, factories, adapters) | `boost/index.md` (an index; its factory rows route on through group indexes -- follow them to the terminal reference) |

## Architecture (LAWs 19-36)

Layout -- one package per unit, contract and implementations apart:

```
cmd/<app>/main.go                                          boost.Start() + fxfact.NewApp(modules...) only
internal/app/<app>/<transport>/handler/<name>/handler.go   one Handle method
internal/pkg/domain/model/entity/<entity>.go               entities, no driver/json tags
internal/pkg/domain/repository/<entity>/repository.go      Repository interface ONLY
internal/pkg/domain/service/<usecase>/service.go           Service interface ONLY, one method
internal/pkg/domain/service/<usecase>/local/service.go     in-process implementation
internal/pkg/datastore/<entity>/<tech>/datastore.go        implements Repository (mongodb, memory, ...)
internal/pkg/datastore/<entity>/<tech>/config.go           that implementation's knobs (collection, ...)
internal/pkg/client/<usecase>/<tech>/client.go             same Service, remote (resty, grpc, mcp)
internal/pkg/client/<usecase>/<tech>/config.go             that implementation's knobs (base URL, ...)
internal/pkg/domain/publisher/<event>/publisher.go         Publisher interface ONLY, one method
internal/pkg/publisher/<event>/boost/publisher.go          implements Publisher on boost wrapper/publisher
internal/pkg/fx/modules/<mirrors the unit path>/module.go  wiring + implementation switch
internal/pkg/fx/modules/<mirrors the unit path>/config.go  which implementation is wired + in-domain impl knobs
api/                                                       openapi.yaml, proto/, events/*.json
```

```go
// domain/service/quote/service.go -- the contract, alone
type Service interface {
	Quote(ctx context.Context, req entity.QuoteRequest) (entity.Quote, error)
}

// domain/service/quote/local/service.go
type service struct{ sellers seller.Repository }

func New(sellers seller.Repository) quote.Service { return &service{sellers: sellers} }

// domain/repository/seller/repository.go -- several methods, ONE entity
//go:generate mockery --name Repository --case underscore
type Repository interface {
	UpsertMany(ctx context.Context, sellers []entity.Seller) error
	GetByID(ctx context.Context, id string) (*entity.Seller, error)
	LastUpdatedAt(ctx context.Context) (time.Time, error)
}

// fx/modules/domain/service/quote/module.go -- IoC + config pick the implementation
func Module() fx.Option {
	switch v := Implementation(); v { // this package's config.go, default "local"
	case Local:
		return localquote.Module()
	case Resty:
		return restyquote.Module()
	default: // LAW 4: an unknown value fails the boot, never falls back
		return fx.Error(fmt.Errorf("%s: unknown implementation %q", implementationKey, v))
	}
}
```

- **19** -- No JWT middleware, hand-rolled TLS, or retry loop around an
  internal call when the mesh does it (Istio `RequestAuthentication` +
  `AuthorizationPolicy`, `VirtualService` retries/timeouts). Before writing
  a client/server, check the boost factory for it (`boost/index.md`).
- **20** -- Nothing under `internal/pkg/domain/` imports
  `internal/pkg/datastore/...`, `internal/pkg/client/...`, a driver
  (`mongo-driver`, `resty`, `pgx`), a transport (`net/http`, `echo`,
  `cloudevents`), boost factories, or `boost/wrapper/config` -- which
  implementation is wired is not the domain's business. The handler
  converts the request/event DTO to an entity before calling the service.
- **21** -- Logs via `github.com/xgodev/boost/wrapper/log`; traces/metrics via
  the OpenTelemetry API and boost's per-factory plugins
  (`boost/references/plugins.md`). No package outside the composition root
  imports a vendor SDK (`dd-trace-go`, `newrelic`); the vendor is config.
- **22** -- Exported interface, unexported struct, `New(...)` returns the
  interface. This is deliberate and overrides Go's "accept interfaces,
  return structs": the caller must never be able to name the
  implementation. Mocks come from `mockery` via `//go:generate` on the
  interface. The handler is the edge -- nothing injects it -- so its
  `New` may return `*Handler`.
- **23** -- DI is uber fx through boost (`boost/references/fx/modules.md`),
  always, even for a small service. Each unit ships `Module() fx.Option`;
  `main.go` only composes modules. The implementation switch exists only
  when two or more implementations exist; with one, the module provides it
  directly. No `init()` that builds a client, no package-level
  client/singleton, no `New` called inside another unit's logic. Adding the
  second implementation adds the switch in the same change: the config
  key, the existing implementation as its default, and the boot failure on
  an unknown value.
- **24** -- One handler package per operation (`handler/<name>/`, one
  `Handle`); one service package per use case (one interface method). A
  repository groups one entity's methods; one datastore implements one
  repository, never two.
- **25** -- `github.com/xgodev/boost/wrapper/config`: `config.Add(key,
  default, description)` in the owner package's `config.go`, with `root`
  = the package path in dots (`internal.pkg.client.quote.resty`) plus an
  accessor func. The owner of "which implementation" is the fx module that
  switches on it; the owner of one implementation's knob (base URL,
  timeout, collection) is that implementation's package -- except an
  in-domain implementation (`service/<usecase>/local`), which cannot import
  config (LAW 20): its knobs live in its fx module's `config.go` and reach
  it through `New`. The env override
  is derived from the key (`boost/references/wrapper/config.md`). Read accessors in the fx module
  and pass values into constructors -- a service never calls `config.*` in
  its logic. `os.Getenv` in app code is a defect. Default datastore is
  `memory` (LAW 8).
- **26** -- No package-level mutable state (maps, slices, counters) serving
  requests. A cache shared across instances goes through
  `boost/wrapper/cache` with a Redis driver; an in-process cache holds only
  data any instance can rebuild.
- **27** -- Checkers via `boost/extra/health` (`health.Add`), served with
  `restresponse.NewHealth` on the readiness route; liveness is a static
  handler (`boost/references/extra/health.md`). Anything you start (workers,
  consumers) drains in an `fx.Lifecycle` `OnStop` hook bounded by its
  context.
- **28** -- The spec lives in `api/`; tests validate handler responses and
  client requests against it (e.g. `github.com/getkin/kin-openapi`'s
  `openapi3filter` for OpenAPI). Server/client code may be generated from
  it; never the reverse.
- **29** -- golang-standards/project-layout: `cmd/<app>/`, `internal/`
  (`internal/app`, `internal/pkg`), `api/`, `configs/`, `deployments/`,
  `scripts/`, `test/`, `docs/`; `pkg/` only for code another repo imports;
  never `src/`. The layout above is that standard specialised.
- **30** -- boost is the framework: boot and wiring (`boost.Start()` + fx),
  config (`boost/wrapper/config`), logs (`boost/wrapper/log`), servers,
  clients and datastores from its factories (`boost/index.md`). A factory
  boost lacks is an issue or a contribution to `xgodev/boost`, never a
  hand-rolled client or a standalone SDK wired around boost.
- **32** -- one `datastore/<entity>/<tech>/` per store, built from its
  boost factory (cassandra, redis, mongo, elasticsearch, pgx --
  `boost/references/factory.md`); the wired store is chosen by config,
  `memory` by default (LAW 8).
- **33** -- one `internal/app/<app>/<transport>/` per protocol (`rest` on
  echo, `grpc`, `mcp`, `cloudevents`, a CLI on cobra), each server from its
  boost factory and switched on by config; every transport's handlers call
  the same `Service`. A protocol boost has no factory for follows LAW 30.
- **34** -- The domain owns `domain/publisher/<event>.Publisher` (one
  method, the entity in, `error` out). Its implementation builds the
  CloudEvent and calls `github.com/xgodev/boost/wrapper/publisher`; the
  per-broker implementations are boost's drivers (`confluentinc` Kafka,
  `nats-io`, `cloud.google.com` Pub/Sub, `extra/noop`), each an fx module
  under `boost/fx/modules/wrapper/publisher/driver/`. The app's fx module
  switches on its own key and wires exactly one driver module, `noop` by
  default (LAW 8). A consumer is a handler under
  `internal/app/<app>/<transport>/` calling the service
  (`boost/references/wrapper/publisher.md`).
- **35** -- Every factory the service uses gets its observability plugins
  (`boost/references/plugins.md` is the matrix), each with its own
  `.enabled` key (`boost.factory.echo.plugins.prometheus.enabled`); config
  turns on the metrics and ONE tracing vendor, OTel or Datadog, never both
  (`boost/references/factory/datadog.md`). The OTel exporters come
  from `factory/contrib/go.opentelemetry.io/otel/v1`
  (`boost.factory.otel.trace.enabled`, `.metric.enabled`, `.endpoint`). A
  component with no boost plugin (Kafka, NATS, Pub/Sub, the publish path's
  trace) is instrumented at the call site with the OTel API: the publisher
  injects the trace context into the event (`traceparent`) and the consumer
  extracts it.
- **36** -- A flag is `config.Add(root+".enabled", <default>, "...")` in the
  owner's `config.go` with an `IsEnabled()` accessor, and the fx module
  returns an empty `fx.Options()` when it is off -- the shape of boost's own
  modules (`fx/modules/wrapper/publisher/driver/*/module.go`) -- so off
  wires nothing. A capability another unit depends on (a publisher) is
  turned off by its implementation switch instead: off is its no-op
  implementation, one key, never an `.enabled` beside a driver key that can
  disagree with it. The domain never reads a flag; a flag that changes
  in-domain behavior reaches it through `New`, like any knob (LAW 25).

## Errors (LAWs 18, 7, 4)

- `_ = err` requires an adjacent `// intentional: <reason>` -- a bare
  discard is indistinguishable from a swallowed defect. `errcheck` (via
  golangci-lint) exists to catch exactly these; do not silence it
  file-wide.
- Libraries return errors; they do not `fmt.Println`/`log.Fatal` as
  handling. `log.Fatal` in a library kills the caller's process --
  that decision belongs to `main`.
- Plain Go: wrap with `%w` so `errors.Is`/`errors.As` keep matching
  (LAW 7); a `fmt.Errorf("failed: %v", err)` wrap erases the type the
  edge matches on.
- boost service: the error package is boost's
  `github.com/xgodev/boost/model/errors`, imported unaliased as
  `errors` -- never `bootsterrors` or any alias. It exports `Is`, `New`,
  `Errorf`, `Wrap`, `Cause`, so it takes the stdlib one's place; alias the
  stdlib (`stderrors`) only where `As`/`Unwrap` is needed.
- boost service: a contract promises boost kinds (LAW 7), never sentinels
  of its own -- no `errors.go` beside the interface. The interface doc
  names the kind, the implementation returns it
  (`errors.NotFoundf("order %s", id)`, `errors.AlreadyExistsf(...)`), a
  caller tests `errors.IsNotFound(err)`. Only an error no kind fits is
  declared, registered with `errors.Register(ErrX, errors.KindConflict)`
  at boot (`boost/references/model-errors.md`).
- boost service: an error that reaches the edge is wrapped with
  `errors.Wrap`, never `fmt.Errorf` -- boost's `Classify` does not
  see through `%w` (`boost/references/model-errors.md`). `fmt.Errorf`
  stays fine for a boot-time error that never reaches the edge
  (`fx.Error`).

## Tests (LAWs 14, 15, 17, 37)

- Fixtures: versioned in the repo or created under `t.TempDir()` --
  never a path under the developer's `$HOME`, never the dev's real
  config as input. Local-only data gates behind an explicit env var and
  skips loudly (`t.Skipf`) when absent.
- `time.Sleep` is never synchronisation (LAW 17): wait on a channel,
  `sync.WaitGroup`, `context.WithTimeout`, or a bounded poll with a
  deadline. A test that sleeps "so the goroutine finishes" is a
  scheduled race.
- `err == nil` alone is a success-only assert (LAW 15) -- assert the
  VALUE too.
- `t.Skip` on a currently-failing test silences a known regression --
  xfail list that alarms on pass, never a skip.
- Coverage (LAW 37): `go test -race -covermode=atomic
  -coverprofile=cover.out ./...` and `go tool cover -func=cover.out` totals
  100.0% with generated code (mockery mocks, `*.pb.go`) dropped from the
  profile. Each flagged module is tested on and off. The module list `main`
  composes lives in one exported func, and a test passes it to
  `fx.ValidateApp` -- that proves the graph, so `main.go` stays wiring only.

## Suppression and escapes (LAW 16)

- `//nolint` is per-line, names the linter (`//nolint:errcheck`), and
  carries a reason on the same line. A file-wide or bare `//nolint`
  pre-approves every future violation in scope.
- `unsafe.Pointer` and `//go:linkname` carry the written invariant that
  makes them sound, same as any safety escape.

## Concurrency (LAW 12)

- Independent work items get a bounded worker pool (`errgroup` with
  `SetLimit`, or channel-fed workers) from line one, concurrent by
  default. Shared state is either owned by one goroutine (channels) or
  guarded -- run `-race` in tests always.
