**REQUIRED BACKGROUND:** `references/start.md`. Each fx module typically wires components covered by a sibling skill (`references/factory/echo.md`, `references/bootstrap/function.md`, etc.).

## When to reach for fx

Always. Inversion of control is a LAW (`engineering/rules.md` LAW 23, Go
shape in `golang/index.md`): every service is wired by fx, even a one-binary
service with two handlers -- hand-wiring in `main` is the global-construction
the LAW forbids, and it is what makes the in-process -> remote swap an edit
instead of a config change. Each unit ships its own `Module() fx.Option`
in the module pattern below; `main.go` lists only the doors.

| Service shape | Module layout |
|---|---|
| One binary | One module per unit (handler, service, repository + its implementation switch); each includes what it needs; `main.go` lists the doors |
| Multiple binaries sharing the same DB / pubsub / cache wiring | The shared wiring becomes modules reused across binaries |
| 5+ services in a monorepo with the same boost-startup boilerplate | Shared modules live in one core repo; every service's modules include them |

A multi-service platform typically follows the latter pattern: shared modules (DB, Pub/Sub client, publisher, logger) live in one shared core repo, and a service's unit module includes the shared ones it needs (`core.DBModule()` inside the repository module), exactly like a boost module.

## boost SHIPS fx modules -- use them before hand-rolling

`fx/modules/**` contains 56 ready modules (`find fx/modules -name module.go`). **Check this list first; hand-write a module only for something boost does not already provide.** Each exposes `Module() fx.Option` (or `Module[T any]() fx.Option` under `bootstrap/function`), import path `github.com/xgodev/boost/fx/modules/<path below>`:

| Area | Modules |
|---|---|
| core | `core/context` (provides `context.Background`; most other modules already compose it) |
| factory (client/server constructors) | `factory/contrib/labstack/echo/v4`, `.../go-resty/resty/v2`, `.../redis/go-redis/v9` (two entry points: `ClusterModule()` and `ClientModule()`, not `Module()`), `.../go.mongodb.org/mongo-driver/v1`, `.../go.mongodb.org/mongo-driver/v2`, `.../google.golang.org/grpc/v1/server`, `.../elastic/go-elasticsearch/v8`, `.../confluentinc/confluent-kafka-go/v2`, `.../lovoo/goka/v1`, `.../nats-io/nats.go/v1`, `.../cloud.google.com/pubsub/v1`, `.../cloud.google.com/bigquery/v1`, `.../coocood/freecache/v1`, `.../panjf2000/ants/v2`, `.../datadog/dd-trace-go/v1`, `.../cloud.google.com/pubsub/v2`, `.../cloud.google.com/firestore/v1`, `.../gocloud.dev/pubsub/v0`, `.../google.golang.org/grpc/v1/client`, `.../modelcontextprotocol/go-sdk/v1/{server,client}`, `.../go.opentelemetry.io/otel/v1`, `.../prometheus/client_golang/v1` (pusher), `.../allegro/bigcache/v3`, `.../aws/aws-sdk-go-v2/v1`, `.../gocql/gocql/v1`, `.../godror/godror/v0`, `.../jackc/pgx/v5`, `.../graphql-go/graphql/v0`, `.../hashicorp/memdb/v1`, `.../jlaffaye/ftp/v0`, `.../k8s.io/client-go/v0`, `.../mittwald/vaultgo/v0`, `.../tidwall/buntdb/v1` |
| bootstrap function | `bootstrap/function` (`Module[T](m []middleware.AnyErrorMiddleware[T])`); middlewares `bootstrap/function/middleware/{recovery,logger,prometheus,publisher,ignore_errors}`; adapters `bootstrap/function/adapter/contrib/{cloud.google.com/pubsub/v1,cloud.google.com/pubsub/v2,cloudevents/sdk-go/v2/core/http,confluentinc/confluent-kafka-go/v2,nats-io/nats.go/v1}` |
| extra | `extra/multiserver` |
| wrapper publisher | `wrapper/publisher`; drivers `wrapper/publisher/driver/contrib/{cloud.google.com/pubsub/v1,cloud.google.com/pubsub/v2,confluentinc/confluent-kafka-go/v2,lovoo/goka/v1,nats-io/nats.go/v1}` and `wrapper/publisher/driver/extra/noop`; `wrapper/publisher/middleware/prometheus` |

So the Pub/Sub client wiring below is already shipped -- `fx/modules/factory/contrib/cloud.google.com/pubsub/v2` does exactly `fx.Provide(pubsub.NewClient)` plus `contextfx.Module()`. The Pub/Sub v1 and v2 modules (factory, driver, adapter) are both composable; each turns on by its `version` key, `v2` by default (`references/factory/pubsub.md`):

The unit that needs the client includes that module; `main` never lists it:

```go
import pubsubfx "github.com/xgodev/boost/fx/modules/factory/contrib/cloud.google.com/pubsub/v2"

options = fx.Options(pubsubfx.Module(), fx.Provide(pubsub.New)) // inside the unit's once, below
```

## The module pattern -- every module, boost's and the app's

All 34 boost modules guard their options with a package `sync.Once` (`fx/modules/factory/contrib/labstack/echo/v4/module.go`), and every app module copies the shape:

```go
// internal/pkg/fx/modules/datastore/order/postgres/module.go
package postgres

var once sync.Once

// Module provides the postgres order.Repository and everything it needs.
// It yields its options on the first call only, so any number of
// dependents can include it.
func Module() fx.Option {
	options := fx.Options()
	once.Do(func() {
		options = fx.Options(
			contextfx.Module(), // github.com/xgodev/boost/fx/modules/core/context
			pgx.Module(),       // the app's pgx factory module, below
			fx.Provide(postgres.New),
		)
	})
	return options
}
```

- **`sync.Once` per module.** `Module()` returns its options on the first call and an empty `fx.Options()` after, so ten dependents can include it and fx never sees a type provided twice ("already provided").
- **A module includes the modules of everything its constructors receive.** The repository module includes the DB module; the service module includes the repository module; the handler module includes the service module. Including the whole chain is what makes a module work on its own, in `main` and in its test.
- **A module provides only its own unit's constructor.** It never calls `fx.Provide` on another unit's constructor, nor on a type a shipped module provides: `context.Context` comes from `contextfx.Module()`, and a second provider fails the boot.
- **`fx.Options`, not `fx.Module`** -- the shape boost ships.
- **A flag goes before the once** (`if !IsEnabled() { return fx.Options() }`, as boost's publisher drivers do), so off wires nothing and never spends the once.

A switch module runs its switch inside the same once (LAW 23). In an inject/builder app it is generated from `@Default` (`references/builder.md`); write it by hand only without inject. `Module()` only wraps an unexported `module(impl)`, which is the seam the test calls:

```go
// internal/pkg/fx/modules/domain/repository/order/module.go
var once sync.Once

// Module provides the order.Repository the config picks (Implementation,
// default memory). An unknown value fails the boot.
func Module() fx.Option {
	options := fx.Options()
	once.Do(func() { options = module(Implementation()) })
	return options
}

func module(impl string) fx.Option {
	switch impl {
	case Memory:
		return memory.Module()
	case Postgres:
		return postgres.Module()
	default: // LAW 4: never a silent fallback
		return fx.Error(errors.NotValidf("%s: unknown implementation %q", implementationKey, impl))
	}
}
```

A boost factory the app builds with its own plugins or config path gets an app module under `internal/pkg/fx/modules/lib/boost/factory/<factory>/`. Use it when boost ships no module for the factory (pgx) or when the shipped one cannot take the app's plugins. In an inject/builder app a resty, redis or mongo client is not written by hand: `@Inject(index=0, name=quote, plugins=[otel])` on the client parameter generates it (`builder.md`, "Factory clients"); this module is for the factories inject does not build:

```go
// internal/pkg/fx/modules/lib/boost/factory/pgx/module.go
var once sync.Once

// Module provides the *sql.DB from boost's pgx factory with the OTel plugin.
// NewDB pings, so an unreachable database fails the boot.
func Module() fx.Option {
	options := fx.Options()
	once.Do(func() {
		options = fx.Options(
			contextfx.Module(),
			fx.Provide(func(ctx context.Context) (*sql.DB, error) {
				// otelsql reads otel.TracerProvider / MeterProvider, which stay nil until
				// started, and fx builds the DB before any echo plugin starts them. Both
				// calls are once-guarded and do nothing when that signal is off.
				otel.StartTracerProvider(ctx) // factory/contrib/go.opentelemetry.io/otel/v1
				otel.StartMeterProvider(ctx)
				return pgx.NewDB(ctx, otelsql.NewOTel()) // factory/core/database/sql/plugins/contrib/xsam/otelsql/v0
			}),
		)
	})
	return options
}
```

## Doors and `main`

In a builder app (every new app) the doors, `Modules()` and `main.go` below are generated from `@REST`/`@GRPC`/`@Function` (`references/builder.md`); this section is the shape of an app wired by hand.

A door is what takes traffic in. A server (HTTP on echo, gRPC) gets a module under `lib/boost/factory/<factory>/<door>/`. That module:

- includes its handlers' modules;
- builds the server with the required plugins (`factory/echo.md`) and its own config path;
- registers the routes;
- contributes the server to the multiserver group.

Two echo servers need two config paths, because the same path means the same port.

```go
// internal/pkg/fx/modules/lib/boost/factory/echo/rest/module.go
package rest

import (
	server "github.com/xgodev/boost/extra/multiserver"         // the Server interface
	"github.com/xgodev/boost/fx/modules/extra/multiserver"     // ServersGroupKey
	createorderfx "example.com/orders/internal/pkg/fx/modules/app/orders/rest/handler/createorder"
	"example.com/orders/internal/app/orders/rest/handler/createorder"
	// elided: the echo factory, contextfx, and the plugins under the echo factory's
	// plugins/ (rec = native/recover, errorhandler = extra/error_handler)
)

const root = "internal.pkg.fx.modules.lib.boost.factory.echo.rest"

var once sync.Once

// Module provides the REST server, with its plugins and routes, to multiserver.
func Module() fx.Option {
	options := fx.Options()
	once.Do(func() {
		options = fx.Options(
			contextfx.Module(),
			createorderfx.Module(), // the handler, and through it the service and repository
			fx.Provide(fx.Annotated{Group: multiserver.ServersGroupKey, Target: newServer}),
		)
	})
	return options
}

func newServer(ctx context.Context, h *createorder.Handler) (server.Server, error) {
	srv, err := echo.NewServerWithConfigPath(ctx, root,
		rec.Register, requestid.Register, log.Register,
		restresponse.Register, errorhandler.Register, // restresponse first (factory/echo.md)
		otelecho.Register, prometheus.Register)
	if err != nil {
		return nil, err
	}
	srv.POST("/orders", h.Handle)
	return srv, nil
}
```

```go
// cmd/api/main.go
package main

import (
	"github.com/xgodev/boost"
	fxfact "github.com/xgodev/boost/factory/contrib/go.uber.org/fx/v1"
	"github.com/xgodev/boost/fx/modules/extra/multiserver"
	"go.uber.org/fx"
	// the door modules
)

// Modules lists the doors, then multiserver; main_test.go validates it.
func Modules() []fx.Option {
	return []fx.Option{rest.Module(), multiserver.Module()}
}

func main() {
	boost.Start()
	fxfact.NewApp(Modules()...).Run()
}
```

- **`main` lists only door modules, then `multiserver.Module()`** (`fx/modules/extra/multiserver`). It holds no `fx.Provide`, no `fx.Invoke`, and no repository, service or client module: those come in through the doors.
- **`multiserver.Module()` serves from fx lifecycle hooks.** `OnStart` runs
  `Serve` in a goroutine, so `fx.New` returns and `Run()` handles SIGTERM.
  - `OnStop` calls `Shutdown` on every server concurrently and waits for
    the drain, bounded by fx's stop timeout; your own `OnStop` hooks run
    too.
  - Every server stopping on its own (no stop requested) shuts the app
    down with exit code 1; one server down while others run is reported by
    `multiserver.Check` (health). No server in the group fails `fx.New`
    (`multiserver: no servers configured`).
- **A consumer built on `bootstrap/function` runs the same way**: `OnStart`
  runs `Function.Run` in a goroutine, `OnStop` cancels its context and waits;
  `Run` ending on its own exits 0, or 1 on error. Its CloudEvents HTTP
  adapter shares echo's default port, so it gets its own `cmd/<consumer>/`
  binary that includes the same service module.

## Testing a module

The once is a package variable, so a module yields its options once per process: a test binary gets one copy. A second call is empty, and that includes the second run under `go test -count=2`. So capture the options ONCE in a package var or in `TestMain`, never inside a test function. A captured `fx.Option` value can be passed to any number of apps.

- **Leaf module.** Its test has `var leaf = Module()` and runs `fx.ValidateApp(leaf, fx.Populate(&repo))`.
  - `ValidateApp` checks the graph without calling the constructors, so no database is dialed. Its error IS the value under test.
  - When the constructors need no infra (memory), also build it with `fxtest.New(t, leaf, fx.Populate(&repo)).RequireStart()` and assert on `repo` (LAW 15).
- **Switch module.** Its test declares, in this order:
  - `var shared = fx.Options(contextfx.Module(), ...)`, listing every module two or more leaves include;
  - `var leaves = map[string]fx.Option{Memory: module(Memory), Postgres: module(Postgres)}`.

  Package vars initialize in declaration order before any test runs, so `shared` takes those modules' only options. Each known value then passes `fx.ValidateApp(shared, leaves[v], fx.Populate(&repo))`. An unknown value makes `fx.ValidateApp(module("x"))` return the `NotValid` error. If a module is missing from `shared`, the test fails on a missing type; it never passes falsely.
- **Composition root.** `TestMain` runs `boost.Start()` and then captures `modules = Modules()`; the test runs `fx.ValidateApp(modules...)` (Go leaf, LAW 37).
  - A switch reads config inside `Module()`, and config has no provider before `boost.Start()`.
  - This test is what covers every `Module()` wrapper and config accessor. The coverage run therefore uses `-coverpkg=./...`.

## Group annotations -- only two groups exist in boost

boost defines exactly two fx groups (repo-wide grep for `group:"`), both with an exported key constant:

| Group tag | Key constant | Collected type | Consumer |
|---|---|---|---|
| `boostrap.function.adapters` (upstream typo -- copy it verbatim) | `function.BSFunctionAdaptersGroupKey` in `fx/modules/bootstrap/function` | `[]function.CmdFunc[T]` | `fx/modules/bootstrap/function` -- passes them to `fn.Run(ctx, hdl, adapters...)` |
| `extra.multiserver.servers` | `multiserver.ServersGroupKey` in `fx/modules/extra/multiserver` | `[]server.Server` | `fx/modules/extra/multiserver` |

**Middlewares are NOT a group.** They are passed as a plain slice argument: `bootstrap/function.Module[T any](m []middleware.AnyErrorMiddleware[T]) fx.Option`. There is no `bootstrap.function.middleware` group tag, and boost never uses `fx.ResultTags` (zero hits) -- a module annotated into an invented group contributes to nothing.

Producers contribute via `fx.Annotated{Group: ..., Target: ...}` with the exported key constant, never a hand-typed string (this is `fx/modules/bootstrap/function/adapter/contrib/nats-io/nats.go/v1`):

```go
fx.Provide(
    fx.Annotated{
        Group:  function.BSFunctionAdaptersGroupKey,
        Target: nats.New[T],
    },
)
```

## Optional deps -- `optional:"true"`

When a module's behavior changes based on whether something is provided:

```go
type FunctionDeps struct {
    fx.In
    Publisher *publisher.Publisher `optional:"true"`
}
```

If no module provides `*publisher.Publisher`, `FunctionDeps.Publisher` is nil and the consuming code degrades gracefully.

`wrapper/publisher.Publisher` is **not** generic -- `type Publisher struct` with `New(driver Driver, mid ...middleware.AnyErrorMiddleware[[]PublishOutput]) *Publisher`, and that is exactly what `fx/modules/wrapper/publisher` provides. The only `Publisher[T]` in boost is `bootstrap/function/middleware/publisher.Publisher[T]`, a middleware type -- a different thing, and no module provides it directly.

## Red flags

| Red flag | Fix |
|---|---|
| Hand-writing an fx module for a component boost already ships one for (Echo, Resty, Redis, Mongo, gRPC server, Elasticsearch, Kafka, Goka, NATS, Pub/Sub, BigQuery, FreeCache, Ants, Datadog, publisher + drivers, multiserver, function + middlewares/adapters) | Import the shipped module from `fx/modules/**` -- run `find fx/modules -name module.go` before writing one |
| Annotating a provider into an invented group tag (`group:"bootstrap.function.middleware"`) | Only `boostrap.function.adapters` and `extra.multiserver.servers` exist; middlewares are a plain slice argument to `bootstrap/function.Module[T]` |
| Single-binary service wired by hand in `main` ("fx is overkill here") | Wire it with fx -- IoC is a LAW (rules.md LAW 23); split the 200-line main into per-unit modules |
| `fx.New(...).Run()` called BEFORE `boost.Start()` | `boost.Start()` is always first |
| `Module()` without its own `sync.Once` ("only main includes it") | The next dependent that includes it fails the boot with "already provided" -- every module is once-guarded, boost's and the app's |
| `main` lists repository, service, client or factory modules, or calls `fx.Provide` / `fx.Invoke` | `main` lists the door modules, then `multiserver.Module()`; each door includes its handlers' modules, and the chain includes the rest |
| A module calls `fx.Provide` on another unit's constructor, or on `context.Context` | Include that unit's module (`contextfx.Module()` for the context); a module provides only its own unit |
| The implementation switch outside the once, or `default:` falling back to an implementation | The switch runs inside the once through `module(impl)`; `default:` returns `fx.Error` (LAW 4) |
| Two echo servers built with `echo.NewServer` | Each door builds its server with `echo.NewServerWithConfigPath` and its own root; both default to the same port |
| A test calls `Module()` inside a test function, twice, or once per value | The second call is empty (`-count=2` included) and the graph passes falsely; capture options once in a package var or `TestMain`, and test values through `module(v)` with the shared modules captured first |
| The app's pgx module with `otelsql` and no `otel.StartTracerProvider` / `StartMeterProvider` | The DB is built before any echo plugin starts the providers; start them in the DB constructor (both once-guarded) |
| Constructor returning a concrete type when consumers need an interface | Return the interface so swapping implementations doesn't break the graph |
| `fx.Invoke` doing real business logic | Use `fx.Invoke` only for wiring (route registration, lifecycle hooks); business logic lives in the constructed types |
| Per-service copy-paste of the same fx wiring | Extract into a shared module package (e.g., `<orgname>/<core>/fxmodules`) |
