**REQUIRED BACKGROUND:**
- `references/bootstrap/function.md` — handler typing rule.
- `references/factory/pubsub.md` — `*pubsub.Client` construction.
- `references/bootstrap/middleware.md` — recovery/logger/publisher chain.
- `references/extra/middleware.md` — `NewAnyErrorWrapper` for the workaround path.

## Canonical (prototype / dev)

```go
import (
    apubsub "github.com/xgodev/boost/bootstrap/function/adapter/contrib/cloud.google.com/pubsub/v1"
    "github.com/xgodev/boost/bootstrap/function"
)

fn, _ := function.New[*cloudevents.Event](rec, lmi, pmi)
fn.Run(ctx, handle, apubsub.New[*cloudevents.Event](pb))
```

Fine for prototypes. **Not safe for production graceful shutdown** — see next section.

## Production caveat — known ctx-loss

`bootstrap/function/adapter/contrib/cloud.google.com/pubsub/v1/helper.go:51` hard-codes:

```go
if err := subscriber.Subscribe(context.Background()); err != nil { ... }
```

A `signal.NotifyContext` passed to `fn.Run(ctx, ...)` reaches the middleware wrapper but **not** the subscription receive loop. SIGTERM does not gracefully drain in-flight messages.

The same shape exists in the NATS and Kafka adapter helpers.

## Production workaround

Bypass `fn.Run` and drive `NewSubscriber` directly with a signal-aware ctx:

```go
import (
    apubsub "github.com/xgodev/boost/bootstrap/function/adapter/contrib/cloud.google.com/pubsub/v1"
    "github.com/xgodev/boost/extra/middleware"
    "github.com/xgodev/boost/bootstrap/function"
)

ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()

opts, err := apubsub.DefaultOptions()
if err != nil { log.Fatalf("subscriber options: %v", err) }

// TODO(boost-upstream): bootstrap/function/adapter/contrib/cloud.google.com/pubsub/v1/helper.go:51
// hard-codes context.Background(), so fn.Run cannot drain SIGTERM. Bypassing
// helper here and driving NewSubscriber with a signal-aware ctx + the same
// recovery → logger → publisher chain. Collapse back to fn.Run once the
// helper accepts a ctx parameter (track upstream issue).
wrp := middleware.NewAnyErrorWrapper[*cloudevents.Event](
    ctx, "bootstrap", rec, lmi, pmi,
)
wrappedHandler := function.Wrapper[*cloudevents.Event](wrp, handle)

var wg sync.WaitGroup
for _, sub := range opts.Subscriptions {
    wg.Add(1)
    go func(name string) {
        defer wg.Done()
        s := apubsub.NewSubscriber[*cloudevents.Event](pb, wrappedHandler, name, opts)
        if err := s.Subscribe(ctx); err != nil && !errors.Is(err, context.Canceled) {
            log.WithField("subscription", name).Errorf("subscriber exited: %v", err)
        }
    }(sub)
}
<-ctx.Done()
wg.Wait()
```

## The TODO comment is mandatory

The `// TODO(boost-upstream):` block is not optional documentation — it's the marker that says "this is a workaround for a known upstream issue, not a stylistic choice". Without it:
- The next maintainer can't tell whether it's a deliberate divergence or sloppy code.
- When upstream fixes the helper, nobody knows this code can collapse back to `fn.Run`.
- Reviewers can't grep for `boost-upstream` to inventory all such workarounds across the codebase.

## Red flags

| Red flag | Fix |
|---|---|
| `pubsub.Client.Subscription(...).Receive(...)` directly | Use `apubsub.NewSubscriber(...).Subscribe(ctx)` |
| Bypass of `fn.Run` without `// TODO(boost-upstream):` naming `helper.go:51` | Add the comment, OR use canonical `fn.Run` and accept ungraceful shutdown |
| `apubsub.New[T]` returning `T = cloudevents.Event` (value) | `T = *cloudevents.Event` everywhere in the chain |
