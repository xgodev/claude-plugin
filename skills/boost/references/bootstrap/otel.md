**REQUIRED BACKGROUND:** `references/bootstrap/function.md`, `references/bootstrap/middleware.md` (canonical `recovery → logger → publisher` chain — this slots in anywhere, no ordering constraint).

```go
import om "github.com/xgodev/boost/bootstrap/function/middleware/go.opentelemetry.io/otel/v1"

otel := om.NewOpenTelemetry[*cloudevents.Event]()
fn, _ := function.New[*cloudevents.Event](rec, lmi, otel, pmi)
```

`NewOpenTelemetry[T]()` implements the same `middleware.AnyErrorMiddleware[T]` interface as the other function middlewares, so it composes with any subset/order of `recovery`/`logger`/`publisher`/`ignore_errors`/`prometheus`.

## What it instruments

- **Tracing:** opens a span named `ProcessMessage` on tracer `boost_function_tracer`; records the error on the span (`span.RecordError`) when the handler fails; sets `function_name`, `status`, and `processing_duration_ms` span attributes.
- **Metrics:** an `Int64Counter` (`boost_function_messages_processed_total`) and a `Float64Histogram` (`boost_function_message_processing_latency_seconds`, recorded in milliseconds) on meter `boost_function`, both labeled with `status` and `function_name`.

## Red flags

| Red flag | Fix |
|---|---|
| Manually opening spans/counters per handler for the same signal | Use `om.NewOpenTelemetry[T]()` in the chain instead — consistent span/metric names across every function |
| Assuming this middleware must be innermost or outermost like `recovery`/`publisher` | It has no ordering constraint — place it anywhere in the chain |
| Running this alongside `prometheus.md`'s middleware expecting deduplicated metrics | They're independent exporters emitting similarly-named but separate metrics — pick one, or accept both are wired |
| Assuming this covers CloudEvents HTTP transport tracing too | It doesn't — this middleware instruments the function execution pipeline (recovery/logging/metrics scope). The CloudEvents HTTP adapter has its own, narrower-scoped OTel plugin at `bootstrap/function/adapter/contrib/cloudevents/sdk-go/v2/core/http/plugins/contrib/go.opentelemetry.io/contrib/v0` (`(*Otel).Register(ctx, opts) []cehttp.Option`), which instruments only the HTTP send/receive mechanics, not the whole handler chain. Wire both if you need both layers traced. |
