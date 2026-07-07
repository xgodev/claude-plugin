**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/log.md` (logger interop).

```go
import ddfact "github.com/xgodev/boost/factory/contrib/datadog/dd-trace-go/v1"
import "gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"

opts, _ := ddfact.NewOptions()
tracer.Start(
    tracer.WithLogger(ddfact.NewLogger()),
    // ... apply opts ...
)
defer tracer.Stop()
```

`NewLogger()` returns a `ddtrace.Logger` adapter that funnels Datadog's internal logs through boost's `wrapper/log`, so trace/log routing stays unified.

Configure agent host/port, service name, env, version, sampling under `boost.factory.datadog.*` (override `BOOST_FACTORY_DATADOG_*`). Standard Datadog env vars (`DD_AGENT_HOST`, `DD_SERVICE`, ...) also work via koanf.

## Datadog vs OpenTelemetry

| Pick | When |
|---|---|
| `references/factory/datadog.md` | Stack already in Datadog; full APM features (continuous profiler, trace search, RUM) |
| `references/factory/otel.md` | Vendor-neutral pipeline (OTLP collector → Tempo/Jaeger/Honeycomb/...) |

Don't mix — one tracing pipeline per service.

## Red flags

| Red flag | Fix |
|---|---|
| `tracer.Start()` without a custom logger | Pass `tracer.WithLogger(ddfact.NewLogger())` so logs are unified |
| Service name / env via raw `os.Getenv("DD_SERVICE")` | Use `BOOST_FACTORY_DATADOG_SERVICE` (registered via `config.Add`) |
| `tracer.Stop()` missing on shutdown | Add `defer tracer.Stop()` after `tracer.Start` |
