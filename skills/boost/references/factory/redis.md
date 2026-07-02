**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. For cache-abstraction usage on top of Redis → `references/wrapper/cache.md`.

## Canonical examples (ship with boost)

- `factory/contrib/redis/go-redis/v9/examples/client/main.go` — single instance
- `factory/contrib/redis/go-redis/v9/examples/cluster/main.go` — cluster mode

Pick whichever matches your deployment topology.

## Single instance

```go
import redisfact "github.com/xgodev/boost/factory/contrib/redis/go-redis/v9"

rdb, err := redisfact.NewClient(ctx)
if err != nil { log.Fatalf("redis: %v", err) }
defer rdb.Close()
```

## Cluster

```go
rdb, err := redisfact.NewClusterClient(ctx)
```

Configure under `boost.factory.redis.*` (override `BOOST_FACTORY_REDIS_*`).

## Config keys (single vs cluster differ — don't mix them up)

| Topology | Endpoint key | Env override |
|---|---|---|
| Single (`NewClient`) | `boost.factory.redis.client.addr` (one `host:port`) | `BOOST_FACTORY_REDIS_CLIENT_ADDR` |
| Cluster (`NewClusterClient`) | `boost.factory.redis.cluster.addrs` (comma-separated `host:port` list) | `BOOST_FACTORY_REDIS_CLUSTER_ADDRS` |

Common knobs (same prefix): `...dialTimeout`, `...readTimeout`,
`...writeTimeout`, `...maxRetries`, `...minRetryBackoff`,
`...maxRetryBackoff` → `BOOST_FACTORY_REDIS_DIALTIMEOUT`, etc.

The endpoint must be a **resolvable** address from inside the runtime.
In Kubernetes that's the **Service FQDN**
(`<svc>.<ns>.svc.cluster.local:6379`), never a node/master DNS or a
hardcoded IP — the latter fails intermittently with
`dial tcp: lookup ... no such host`. A single-instance service that sets
`...cluster.addrs` (or vice versa) silently connects to nothing.

## Factory vs cache abstraction

| Use case | Reach for |
|---|---|
| Pub/Sub on Redis, streaming, scripting, low-level commands | `references/factory/redis.md` (raw client) |
| Typed cache over a value type with codec + plugins | `references/wrapper/cache.md` |

## Observability plugins

`redisfact.NewClient(ctx, plugins ...Plugin)` also accepts vendor plugins:

| Vendor | Import | Usage |
|---|---|---|
| Datadog | `.../factory/contrib/redis/go-redis/v9/plugins/contrib/datadog/dd-trace-go/v1` | `redisfact.NewClient(ctx, datadog.ClientRegister)` |
| Prometheus | `.../factory/contrib/redis/go-redis/v9/plugins/contrib/prometheus/client_golang/v1` | `redisfact.NewClient(ctx, prometheus.ClientRegister)` |
| OpenTelemetry | `.../factory/contrib/redis/go-redis/v9/plugins/native/otel/v9` | `redisfact.NewClient(ctx, otel.ClientRegister)` |

The OTel one lives under `plugins/native/`, not `plugins/contrib/`, because it delegates to go-redis's own built-in instrumentation (`redisotel.InstrumentTracing`/`InstrumentMetrics`) instead of wrapping the client — same `Register` call shape either way, just note it's not a third-party contrib wrapper like the other two.

## Red flags

| Red flag | Fix |
|---|---|
| `redis.NewClient(&redis.Options{...})` directly | `redisfact.NewClient(ctx)` |
| Cluster vs single decided at runtime by env-sniff | Pick at deploy time; keep a single example shape per service |
| Forgetting `defer rdb.Close()` | Add it |
