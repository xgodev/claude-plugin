**REQUIRED BACKGROUND:**
- `references/bootstrap/function.md` -- handler typing rule.
- `references/bootstrap/middleware.md` -- recovery/logger/publisher chain.
- `references/extra/middleware.md` -- `NewAnyErrorWrapper` for the workaround.
- `references/bootstrap/adapter-pubsub.md` -- same shape, full workaround pattern documented there.

## Canonical (prototype / dev)

```go
import (
    anats "github.com/xgodev/boost/bootstrap/function/adapter/contrib/nats-io/nats.go/v1"
    "github.com/xgodev/boost/bootstrap/function"
)

fn, _ := function.New[*cloudevents.Event](rec, lmi, pmi)
fn.Run(ctx, handle, anats.New[*cloudevents.Event](conn))
```

Subscriptions are configured via `boost.bootstrap.function.adapter.nats.subjects` (list) and `boost.bootstrap.function.adapter.nats.queue` (`config.go:9-12`, struct fields `Options.Subjects` / `Options.Queue` in `options.go:6-9`). Override at deploy via `BOOST_BOOTSTRAP_FUNCTION_ADAPTER_NATS_*`.

## Production caveat -- ctx is discarded entirely

`bootstrap/function/adapter/contrib/nats-io/nats.go/v1/helper.go:44` hard-codes `context.Background()` per subject, and `subscriber.go:62` builds its OWN `context.Background()` for every message.

A signal-aware ctx cannot fix this: `Subscribe(ctx)` ignores its argument outright -- `subscriber.go:34-36` is just `return l.conn.QueueSubscribe(l.subject, l.queue, l.h)`. The handler always receives the background ctx built at `subscriber.go:62`, so cancellation never reaches it and SIGTERM does not gracefully drain. (`Subscribe` also returns `(*nats.Subscription, error)`, so it cannot be chained as a single-value expression.) Bypassing `fn.Run` via `extra/middleware.NewAnyErrorWrapper` still buys you an explicit chain, but not cancellation. Add the `// TODO(boost-upstream):` annotation naming the offending file.

## Queue groups

NATS queue groups distribute messages across N subscribers (load balancing). Configure via `boost.bootstrap.function.adapter.nats.queue`. Without a queue group, every subscriber gets every message (broadcast).

## Red flags

| Red flag | Fix |
|---|---|
| `nats.Conn.Subscribe(...)` directly from the upstream SDK | Use `anats.NewSubscriber(...)` (its `Subscribe` returns `(*nats.Subscription, error)`) or `function.New + fn.Run` |
| Bypass of `fn.Run` without `// TODO(boost-upstream):` naming `helper.go:44`/`subscriber.go:62` | Add the comment, OR accept ungraceful shutdown |
| Multiple NATS connections per process | Construct one `*nats.Conn` at startup, share |
| Config tunables read via `os.Getenv` | Use `BOOST_BOOTSTRAP_FUNCTION_ADAPTER_NATS_*` overrides |
