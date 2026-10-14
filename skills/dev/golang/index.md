# Go -- language leaf

Go-concrete shapes of the language-agnostic LAWs in
`../engineering/rules.md` (read that first; numbers below refer to it),
plus the routes to Go frameworks. This file exists because rules.md is
language-agnostic BY LAW -- the Go idioms live here, not there.

## Routes

| Context | Reference |
|---|---|
| github.com/xgodev/boost -- the Go service framework (any boost import, boot/wiring, factories, adapters) | `boost/index.md` (an index; its factory rows route on through group indexes -- follow them to the terminal reference) |

## Architecture (LAWs 19-28)

Layout -- one package per unit, contract and implementations apart:

```
cmd/<app>/main.go                                          fx.New(modules...) only
internal/app/<app>/<transport>/handler/<name>/handler.go   one Handle method
internal/pkg/domain/model/entity/<entity>.go               entities, no driver/json tags
internal/pkg/domain/repository/<entity>/repository.go      Repository interface ONLY
internal/pkg/domain/service/<usecase>/service.go           Service interface ONLY, one method
internal/pkg/domain/service/<usecase>/local/service.go     in-process implementation
internal/pkg/datastore/<entity>/<tech>/datastore.go        implements Repository (mongodb, memory, ...)
internal/pkg/datastore/<entity>/<tech>/config.go           that implementation's knobs (collection, ...)
internal/pkg/client/<usecase>/<tech>/client.go             same Service, remote (resty, grpc, mcp)
internal/pkg/client/<usecase>/<tech>/config.go             that implementation's knobs (base URL, ...)
internal/pkg/fx/modules/<mirrors the unit path>/module.go  wiring + implementation switch
internal/pkg/fx/modules/<mirrors the unit path>/config.go  key: which implementation is wired
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
  interface. The handler is the edge -- nothing injects it -- so
  `NewHandler` may return `*Handler`.
- **23** -- DI is uber fx through boost (`boost/references/fx/modules.md`),
  always, even for a small service. Each unit ships `Module() fx.Option`;
  `main.go` only composes modules. No `init()` that builds a client, no
  package-level client/singleton, no `New` called inside another unit's
  logic.
- **24** -- One handler package per operation (`handler/<name>/`, one
  `Handle`); one service package per use case (one interface method). A
  repository groups one entity's methods; one datastore implements one
  repository, never two.
- **25** -- `github.com/xgodev/boost/wrapper/config`: `config.Add(key,
  default, description)` in the owner package's `config.go`, with `root`
  = the package path in dots (`internal.pkg.client.quote.resty`) plus an
  accessor func. The owner of "which implementation" is the fx module that
  switches on it; the owner of one implementation's knob (base URL,
  timeout, collection) is that implementation's package. The env override
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

## Errors (LAWs 18, 7, 4)

- `_ = err` requires an adjacent `// intentional: <reason>` -- a bare
  discard is indistinguishable from a swallowed defect. `errcheck` (via
  golangci-lint) exists to catch exactly these; do not silence it
  file-wide.
- Libraries return errors; they do not `fmt.Println`/`log.Fatal` as
  handling. `log.Fatal` in a library kills the caller's process --
  that decision belongs to `main`.
- Wrap with `%w` so `errors.Is`/`errors.As` keep matching (LAW 7);
  a `fmt.Errorf("failed: %v", err)` wrap erases the type the edge
  matches on.

## Tests (LAWs 14, 15, 17)

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
