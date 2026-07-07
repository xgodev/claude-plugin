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

Configure endpoint, headers, compression, batch settings under `boost.factory.otel.*` (override `BOOST_FACTORY_OTEL_*`). Standard OTel env vars (`OTEL_EXPORTER_OTLP_ENDPOINT`, etc.) are honored too via koanf.

## Red flags

| Red flag | Fix |
|---|---|
| `otlptrace.New(...)` from upstream SDK directly | `otelfact.NewTracerExporter(ctx, opts)` |
| Endpoint via raw `os.Getenv("OTEL_*")` | Register the equivalent boost key via `config.Add` so it shows in the boot banner |
| Building MeterProvider per request | Build once at startup |
