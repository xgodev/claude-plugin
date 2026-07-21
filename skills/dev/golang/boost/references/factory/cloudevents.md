**REQUIRED BACKGROUND:** `references/start.md`, `references/bootstrap/function.md` (handler typing). For pub/sub-based CloudEvents flows -> `references/bootstrap/adapter-pubsub.md` / `-nats` / `-kafka`.

```go
import cefact "github.com/xgodev/boost/factory/contrib/cloudevents/sdk-go/v2"

c := cefact.NewHTTP(ctx, handler) // *cefact.Client -- boost's own wrapper
c.Start(ctx)                       // starts the receiver (blocks); NewHTTP alone receives nothing
```

Use this when your function is invoked via HTTP CloudEvents (Knative push, Cloud Run Eventarc HTTP trigger, GitHub webhook bridge) instead of broker-pull. The handler signature follows `references/bootstrap/function.md`'s `Handler[T]` rule (input value, output pointer).

## Red flags

| Red flag | Fix |
|---|---|
| `cloudevents.NewClientHTTP(...)` from upstream SDK directly | `cefact.NewHTTP(ctx, handler)` |
| Bypassing the function middleware chain when running over HTTP | Use the bootstrap HTTP adapter (`bootstrap/function/adapter/contrib/cloudevents/sdk-go/v2/core/http`, `Run(fn, opts, plugins...)`) -- it wraps the `function.Handler[T]` itself; `function.Wrapper` does NOT produce a `cefact.Handler` |
