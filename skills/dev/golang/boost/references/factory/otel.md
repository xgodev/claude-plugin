**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

## Tracer exporter

```go
import otelfact "github.com/xgodev/boost/factory/contrib/go.opentelemetry.io/otel/v1"

opts, _ := otelfact.NewOptions()
exp, err := otelfact.NewTracerExporter(ctx, opts)
if err != nil { log.Fatalf("otel tracer: %v", err) }
// register exp into a TracerProvider
```

## Metric exporter

```go
exp, _ := otelfact.NewMeterExporter(ctx, opts)        // chooses HTTP or gRPC based on options
exp, _ := otelfact.NewGRPCMeterExporter(ctx, opts)    // explicit gRPC
exp, _ := otelfact.NewHTTPMeterExporter(ctx, opts)    // explicit HTTP

reader, _ := otelfact.NewReader(opts, exp)
// register reader into a MeterProvider
```

`NewMeter(name, ...)` is a convenience over the global MeterProvider once it's set up.

## Built before `Start*Provider`

The package globals `TracerProvider` and `MeterProvider` start as OpenTelemetry's global delegates, which forward to the provider `StartTracerProvider`/`StartMeterProvider` registers. A component built before that (an fx-built `*sql.DB` with the otelsql plugin, a redis or mongo client) does not panic and reports to the real provider once it starts; `NewTracer`/`NewMeter` before `Start` are safe the same way.

Something still has to start them, and no OTel plugin does (the echo one included). In an fx app that is `Module()` from `github.com/xgodev/boost/fx/modules/factory/contrib/go.opentelemetry.io/otel/v1` (`otelfx`), included by every module whose component takes an OTel plugin (`references/fx/modules.md`); without it every span and metric goes to a noop provider and nothing errors. In a builder app it is generated: a door whose `@Server` lists `otel` (rest, mcp, cloudevents), a `@Function` with the `opentelemetry` middleware, and the module of an `@Inject` client with the `otel` plugin (resty, redis, mongo, sql) include it -- add it by hand only outside builder/inject.

## Shutdown -- flush on stop

`otelfact.Shutdown(ctx)` exports what the providers still hold (the span batch, the metrics since the last export) and stops both at once within `ctx`; the error joins both. It is final: nothing records after it, a later `Start*Provider` only logs a warning, a second `Shutdown` returns nil. `otelfx.Module()` calls it in an OnStop hook within the stop context, and logs a failure (an unreachable collector) at ERROR without failing the stop, so a job that succeeded still exits 0. Without it a stop drops the queued spans and the metrics since the last interval (60s default), and a short job can exit before its first export. Never call it by hand in an fx app.

Configure `.endpoint` (default `localhost:4317`), `.protocol` (`grpc` default, or `http`), `.insecure` (default `true`), `.tls.cert`, `.trace.enabled` / `.metric.enabled` (default `true`) / `.console.enabled`, `.trace.ratio` (default `1.0`), per-signal `.trace.endpoint` / `.metric.endpoint` / `.trace.protocol` / `.metric.protocol`, `.env`, `.version`, `.attributes` and `.export.interval` (60s) / `.export.timeout` (30s) under `boost.factory.otel.*` (override `BOOST_FACTORY_OTEL_*`). There are no headers or compression keys. Standard OTel env vars are honored too; `OTEL_EXPORTER_OTLP_ENDPOINT`, when set, wins over `.endpoint`.

## Testing -- `oteltest.Collector`

```go
import "github.com/xgodev/boost/factory/contrib/go.opentelemetry.io/otel/v1/oteltest"

collector, err := oteltest.NewCollector() // in-process OTLP/gRPC collector on a loopback port
require.NoError(t, err)
t.Cleanup(collector.Close)
t.Setenv("BOOST_FACTORY_OTEL_ENDPOINT", collector.Endpoint()) // before boost.Start()

boost.Start()
// ... start the app, call it, stop it (the stop flushes) ...
require.Contains(t, collector.Spans(), "GET /stock/:sku") // Metrics() for metric names
```

The providers start once per process and `Shutdown` is final, so a test package runs the app lifecycle with OTel once (capture the once-guarded `Module()` in `TestMain`); a second run in the same binary exports nothing. An app with otel and no collector reachable retries the export for seconds when it stops -- point tests at a `Collector` or turn `.trace.enabled` / `.metric.enabled` off.

## Red flags

| Red flag | Fix |
|---|---|
| `otlptrace.New(...)` from upstream SDK directly | `otelfact.NewTracerExporter(ctx, opts)` |
| Endpoint via raw `os.Getenv("OTEL_*")` | Register the equivalent boost key via `config.Add` so it shows in the boot banner |
| Building MeterProvider per request | Build once at startup |
| `otelfx.Module()` added by hand to a builder app | builder/inject already include it for every `otel` plugin and the `opentelemetry` middleware |
| `otelfact.Shutdown` called in `main` or an OnStop of your own | `otelfx.Module()` already does it on stop; it is final, so a second call flushes nothing |
| A telemetry test that needs a collector running on the machine | `oteltest.NewCollector()` + `BOOST_FACTORY_OTEL_ENDPOINT=collector.Endpoint()` before `boost.Start()` |
