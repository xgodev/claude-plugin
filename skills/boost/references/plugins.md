Most factory constructors accept a variadic `plugins ...Plugin` argument, and each factory's own reference file lists everything it supports — not just observability. Echo alone has body-dump/limit, CORS, gzip, two JSON-codec swaps, pprof, Swagger UI, and a semaphore, in addition to Datadog/OTel/Prometheus; Resty has request-ID and retry; gRPC has a compressor. **Whenever the task wires or configures a factory, read that factory's own "Plugins" section — don't assume the required/default plugin set shown in its main example is the complete list.**

This file is the narrower cross-cutting index specifically for observability vendors: **when the user names OpenTelemetry, Datadog, or Prometheus, or asks to add tracing/metrics, check this table for every boost component the service actually uses** — coverage is per-component, not automatic. Activating OTel for the service does not activate it for every library; each row below is a separate opt-in. For non-observability plugins (JSON codecs, compression, retry, profiling, docs UI, …), go straight to the component's own reference file instead of this matrix.

| Component | Datadog | OpenTelemetry | Prometheus | Reference |
|---|---|---|---|---|
| Echo (HTTP server) | ✓ | ✓ | ✓ | `references/factory/echo.md` |
| Resty (HTTP client) | ✓ | ✓ | ✓ | `references/factory/resty.md` |
| Redis | ✓ | ✓ (native, not a contrib wrapper) | ✓ | `references/factory/redis.md` |
| Mongo (v1 and v2) | ✓ | ✓ | ✓ | `references/factory/mongo.md` |
| gRPC client | ✓ | ✓ | ✓ | `references/factory/grpc.md` |
| gRPC server | ✓ | — | ✓ | `references/factory/grpc.md` |
| Postgres (pgx) | ✓ | ✓ | — | `references/factory/pgx.md` |
| Oracle (godror) | ✓ | ✓ | — | `references/factory/pgx.md`, `references/factory/godror.md` (shared `database/sql` plugin layer) |
| AWS | ✓ | — | — | `references/factory/aws.md` |
| Hystrix | — | — | ✓ | `references/factory/hystrix.md` |
| Function chain (whole handler: recovery/logger/publisher) | — | ✓ | ✓ | `references/bootstrap/otel.md`, `references/bootstrap/prometheus.md` |
| CloudEvents HTTP adapter (transport layer only, narrower scope than the function chain above) | — | ✓ | — | `references/bootstrap/otel.md` (see its "assuming this covers CloudEvents..." red flag) |
| `extra/middleware` chain (circuit breaker + tracing on hand-built middleware, not `fn.Run`) | ✓ | — | ✓ (also Hystrix here, a resilience plugin not an observability one) | `references/extra/middleware.md` |

No plugin layer exists (verified against source) for: Cassandra, Elasticsearch, Kafka, NATS, Pub/Sub, gocloud.dev Pub/Sub, Goka, CloudEvents (factory-level), Cobra, K8s, FTP, net/http2, Vault, BigQuery, Firestore, BuntDB, MemDB, BigCache, FreeCache, Ants, GCP API/gRPC composition, GraphQL, Zap, Zerolog, Logrus, language(i18n). If the service uses one of these and needs tracing/metrics, instrument it directly at the call site — there is no boost-provided plugin to activate.

## Red flags

| Red flag | Fix |
|---|---|
| Wiring OTel for the function chain and assuming every factory (DB, HTTP client, cache) is now traced too | Check this table — each component needs its own plugin activated separately |
| Assuming a vendor plugin exists for every factory | Several components (Cassandra, Kafka, NATS, …) have none — check the "No plugin layer exists" list before promising instrumentation |
| Treating gRPC client and server as having identical plugin coverage | Server has no OTel plugin; client does |
| Confusing `extra/middleware`'s plugins with a factory's `plugins ...Plugin` | Different plugin systems, same vendor names — `extra/middleware.md` plugins wrap `AnyErrorMiddleware`, not a factory constructor |
