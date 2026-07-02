**REQUIRED BACKGROUND:** `references/start.md`, `references/bootstrap/function.md` (handler typing). For pub/sub-based CloudEvents flows → `references/bootstrap/adapter-pubsub.md` / `-nats` / `-kafka`.

```go
import cefact "github.com/xgodev/boost/factory/contrib/cloudevents/sdk-go/v2"

c := cefact.NewHTTP(ctx, handler)
// c is a cloudevents.Client wired with HTTP transport
```

Use this when your function is invoked via HTTP CloudEvents (Knative push, Cloud Run Eventarc HTTP trigger, GitHub webhook bridge) instead of broker-pull. The handler signature follows `references/bootstrap/function.md`'s `Handler[T]` rule (input value, output pointer).

## Red flags

| Red flag | Fix |
|---|---|
| `cloudevents.NewClientHTTP(...)` from upstream SDK directly | `cefact.NewHTTP(ctx, handler)` |
| Bypassing the function middleware chain when running over HTTP | Wire `function.Wrapper[*cloudevents.Event]` over the handler before passing to `NewHTTP` |
