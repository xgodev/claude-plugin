**REQUIRED BACKGROUND:**
- `references/bootstrap/function.md` -- handler typing rule.
- `references/factory/pubsub.md` -- `*pubsub.Client` construction.
- `references/bootstrap/middleware.md` -- recovery/logger/publisher chain.

## Canonical

```go
import (
    apubsub "github.com/xgodev/boost/bootstrap/function/adapter/contrib/cloud.google.com/pubsub/v2"
    "github.com/xgodev/boost/bootstrap/function"
)

ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()

fn, _ := function.New[*cloudevents.Event](rec, lmi, pmi)
if err := fn.Run(ctx, handle, apubsub.New[*cloudevents.Event](pb)); err != nil { ... }
```

Safe for production. The command runs `Helper.Run` on its context: it receives every subscription concurrently and blocks until the context is done, then takes no new message, lets the handler finish the one it holds with a context the stop does not cancel, stops retrying, and returns. A subscription that cannot be received stops the others and fails `Run` with an error naming it, so the boot fails instead of running without it. v1 (`cloud.google.com/pubsub/v1`) behaves the same and gives a failed message back instead of retrying it while stopping. `Helper.Start` is deprecated.

In a builder app the adapter reads with the app's v2 `*pubsub.Client` (`ModuleWithoutClient`, or `ModuleWithNamedClient` for `@Function(client=x)`); v1 builds its own v1 client whatever `boost.factory.gcp.pubsub.version` says. The adapter understands binary-mode CloudEvents only (`ce_*` attributes).

## Red flags

| Red flag | Fix |
|---|---|
| `pb.Subscriber(...).Receive(...)` directly | Use `apubsub.NewSubscriber(...).Subscribe(ctx)` |
| `fn.Run` bypassed with `NewSubscriber` + a hand-made signal loop (the old ctx-loss workaround) | Collapse back to `fn.Run(ctx, ...)` with a signal-aware ctx; drop the `TODO(boost-upstream)` |
| `apubsub.New[T]` returning `T = cloudevents.Event` (value) | `T = *cloudevents.Event` everywhere in the chain |
