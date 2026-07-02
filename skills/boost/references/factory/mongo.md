**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

## Canonical examples (ship with boost)

- `factory/contrib/go.mongodb.org/mongo-driver/v1/examples/ping/main.go`
- `factory/contrib/go.mongodb.org/mongo-driver/v2/examples/ping/main.go`

Read those before writing new wiring — they are the framework's authoritative shape.

## Choose v1 or v2

Pick the version that matches the mongo-driver major your service depends on. Both expose the same boost constructor trio — but the underlying `mongo.Connect` signature they wrap changed between majors: v1's is `mongo.Connect(ctx, co)` (context required), v2's dropped the context parameter (`mongo.Connect(co)`). This only matters if you're reading the factory's own source or writing code that calls the driver directly outside the factory — the boost constructors below hide the difference.

## Construction

```go
import mongofact "github.com/xgodev/boost/factory/contrib/go.mongodb.org/mongo-driver/v2"

conn, err := mongofact.NewConn(ctx)
if err != nil { log.Fatalf("mongo: %v", err) }
defer conn.Close(ctx)
```

Configure via `boost.factory.mongo.*` (override `BOOST_FACTORY_MONGO_*`). Multi-database: `mongofact.ConfigAdd("boost.factory.mongo.<name>")` per logical DB + `NewConnWithConfigPath`.

## Observability plugins

Same plugin set on both v1 and v2 (swap the import's version segment):

| Vendor | Import | Usage |
|---|---|---|
| Datadog | `.../factory/contrib/go.mongodb.org/mongo-driver/v2/plugins/contrib/datadog/dd-trace-go/v1` | `mongofact.NewConn(ctx, datadog.NewDatadog().Register)` |
| OpenTelemetry | `.../factory/contrib/go.mongodb.org/mongo-driver/v2/plugins/contrib/go.opentelemetry.io/contrib/v0` | `..., contrib.NewOtelMongo().Register)` |
| Prometheus | `.../factory/contrib/go.mongodb.org/mongo-driver/v2/plugins/contrib/prometheus/client_golang/v1` | `..., prometheus.NewPrometheus().Register)` |

## Red flags

| Red flag | Fix |
|---|---|
| `mongo.Connect(ctx, ...)` directly from upstream SDK | `mongofact.NewConn(ctx)` |
| URI via `os.Getenv` | `BOOST_FACTORY_MONGO_*` |
| Forgetting `defer conn.Close(ctx)` | Add it |
