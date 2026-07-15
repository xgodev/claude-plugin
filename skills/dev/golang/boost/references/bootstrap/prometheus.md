**REQUIRED BACKGROUND:** `references/bootstrap/function.md`, `references/bootstrap/middleware.md` (canonical `recovery → logger → publisher` chain — this slots in anywhere, no ordering constraint).

```go
import pm "github.com/xgodev/boost/bootstrap/function/middleware/prometheus"

prom := pm.NewPrometheus[*cloudevents.Event]()
fn, _ := function.New[*cloudevents.Event](rec, lmi, prom, pmi)
```

`NewPrometheus[T]()` implements the same `middleware.AnyErrorMiddleware[T]` interface as the other function middlewares, so it composes with any subset/order of `recovery`/`logger`/`publisher`/`ignore_errors`.

## What it captures

| Metric | Type | Labels |
|---|---|---|
| `boost_function_messages_processed_total` | Counter | `status`, `function_name` |
| `boost_function_message_processing_latency_seconds` | Histogram (default buckets) | — |

`function_name` comes from `boost.ApplicationName()`; `status` is `success` or `error` based on whether the wrapped handler returned an error.

## Red flags

| Red flag | Fix |
|---|---|
| Hand-instrumenting handlers with a package-level `prometheus.Counter` | Use `pm.NewPrometheus[T]()` in the middleware chain instead — consistent labels across every function |
| Assuming this middleware must be innermost or outermost like `recovery`/`publisher` | It has no ordering constraint — place it anywhere in the chain |
