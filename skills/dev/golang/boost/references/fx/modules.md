**REQUIRED BACKGROUND:** `references/start.md`. Each fx module typically wires components covered by a sibling skill (`references/factory/echo.md`, `references/bootstrap/function.md`, etc.).

## When to reach for fx

| Service shape | Recommendation |
|---|---|
| 1 main.go with handlers + dependencies wired by hand | Don't use fx -- manual wiring is clearer |
| Multiple binaries sharing the same DB / pubsub / cache wiring | Extract those into fx modules; reuse across binaries |
| 5+ services in a monorepo with the same boost-startup boilerplate | Use fx modules; standardize the boilerplate |

A multi-service platform typically follows the latter pattern: shared modules (DB, Pub/Sub client, publisher, logger) live in one shared core repo and every service composes them via `fx.Options(core.PubsubModule(), core.DBModule(), ...).Run()`.

## boost SHIPS fx modules -- use them before hand-rolling

`fx/modules/**` contains 34 ready modules (`find fx/modules -name module.go`). **Check this list first; hand-write a module only for something boost does not already provide.** Each exposes `Module() fx.Option` (or `Module[T any]() fx.Option` under `bootstrap/function`), import path `github.com/xgodev/boost/fx/modules/<path below>`:

| Area | Modules |
|---|---|
| core | `core/context` (provides `context.Background`; most other modules already compose it) |
| factory (client/server constructors) | `factory/contrib/labstack/echo/v4`, `.../go-resty/resty/v2`, `.../redis/go-redis/v9` (two entry points: `ClusterModule()` and `ClientModule()`, not `Module()`), `.../go.mongodb.org/mongo-driver/v1`, `.../go.mongodb.org/mongo-driver/v2`, `.../google.golang.org/grpc/v1/server`, `.../elastic/go-elasticsearch/v8`, `.../confluentinc/confluent-kafka-go/v2`, `.../lovoo/goka/v1`, `.../nats-io/nats.go/v1`, `.../cloud.google.com/pubsub/v1`, `.../cloud.google.com/bigquery/v1`, `.../coocood/freecache/v1`, `.../panjf2000/ants/v2`, `.../datadog/dd-trace-go/v1` |
| bootstrap function | `bootstrap/function` (`Module[T](m []middleware.AnyErrorMiddleware[T])`); middlewares `bootstrap/function/middleware/{recovery,logger,prometheus,publisher,ignore_errors}`; adapters `bootstrap/function/adapter/contrib/{cloud.google.com/pubsub/v1,cloudevents/sdk-go/v2/core/http,confluentinc/confluent-kafka-go/v2,nats-io/nats.go/v1}` |
| extra | `extra/multiserver` |
| wrapper publisher | `wrapper/publisher`; drivers `wrapper/publisher/driver/contrib/{cloud.google.com/pubsub/v1,confluentinc/confluent-kafka-go/v2,lovoo/goka/v1,nats-io/nats.go/v1}` and `wrapper/publisher/driver/extra/noop`; `wrapper/publisher/middleware/prometheus` |

So the Pub/Sub client wiring below is already shipped -- `fx/modules/factory/contrib/cloud.google.com/pubsub/v1` does exactly `fx.Provide(pubsub.NewClient)` plus `contextfx.Module()`:

```go
import pubsubfx "github.com/xgodev/boost/fx/modules/factory/contrib/cloud.google.com/pubsub/v1"

app := fx.New(pubsubfx.Module(), ...)
```

## Module shape -- the fallback, when nothing shipped fits

```go
package catalogcore

import (
    "go.uber.org/fx"
    "github.com/xgodev/boost/factory/contrib/cloud.google.com/pubsub/v1"
)

func PubsubModule() fx.Option {
    return fx.Module("pubsub",
        fx.Provide(pubsub.NewClient),
        fx.Invoke(registerLifecycleHooks),
    )
}

func registerLifecycleHooks(lc fx.Lifecycle, c *pubsub.Client) {
    lc.Append(fx.Hook{
        OnStop: func(ctx context.Context) error { return c.Close() },
    })
}
```

`fx.Provide(constructor)` makes the constructor's return value available as a dependency. `fx.Invoke(fn)` runs `fn` at startup and threads in whatever it asks for.

## Composition in `main`

```go
func main() {
    boost.Start()

    app := fx.New(
        catalogcore.PubsubModule(),
        catalogcore.DBModule(),
        catalogcore.PublisherModule(),
        fx.Provide(NewOrderService, NewOrderHandler),
        fx.Invoke(registerHTTPRoutes),
    )
    app.Run()
}
```

`app.Run()` blocks until SIGTERM, then runs every `OnStop` hook in reverse-of-start order.

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
| Single-binary service with 200-line main.go using fx | Strip fx; manual wiring is clearer |
| `fx.New(...).Run()` called BEFORE `boost.Start()` | `boost.Start()` is always first |
| Constructor returning a concrete type when consumers need an interface | Return the interface so swapping implementations doesn't break the graph |
| `fx.Invoke` doing real business logic | Use `fx.Invoke` only for wiring (route registration, lifecycle hooks); business logic lives in the constructed types |
| Per-service copy-paste of the same fx wiring | Extract into a shared module package (e.g., `<orgname>/<core>/fxmodules`) |
