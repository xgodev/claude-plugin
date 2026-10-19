**REQUIRED BACKGROUND:**
- `references/bootstrap/function.md` -- handler typing rule.
- `references/bootstrap/middleware.md` -- recovery/logger/publisher chain.
- `references/bootstrap/adapter-pubsub.md` -- same shutdown shape.

## Canonical

```go
import (
    anats "github.com/xgodev/boost/bootstrap/function/adapter/contrib/nats-io/nats.go/v1"
    "github.com/xgodev/boost/bootstrap/function"
)

fn, _ := function.New[*cloudevents.Event](rec, lmi, pmi)
fn.Run(ctx, handle, anats.New[*cloudevents.Event](conn))
```

Subscriptions are configured via `boost.bootstrap.function.adapter.nats.subjects` (list) and `boost.bootstrap.function.adapter.nats.queue` (`config.go:9-12`, struct fields `Options.Subjects` / `Options.Queue` in `options.go:6-9`). Override at deploy via `BOOST_BOOTSTRAP_FUNCTION_ADAPTER_NATS_*`.

## Shutdown

`fn.Run(ctx, ...)` runs `Helper.Run(ctx)`: it subscribes every subject, blocks until `ctx` is done, then drains the subscriptions, so the handler finishes the message it holds (its context is not the run context, so the stop does not cancel it) and SIGTERM exits 0. A subject that cannot be subscribed fails `Run`. `cloudevents_nats` (`cenats`) behaves the same. `Helper.Start` is deprecated. In a builder app the adapter reads with the app's `*nats.Conn` (`ModuleWithoutClient`, or `ModuleWithNamedClient` for `@Function(client=x)`).

## Queue groups

NATS queue groups distribute messages across N subscribers (load balancing). Configure via `boost.bootstrap.function.adapter.nats.queue`. Without a queue group, every subscriber gets every message (broadcast).

## Red flags

| Red flag | Fix |
|---|---|
| `nats.Conn.Subscribe(...)` directly from the upstream SDK | Use `anats.NewSubscriber(...)` (its `Subscribe` returns `(*nats.Subscription, error)`) or `function.New + fn.Run` |
| `fn.Run` bypassed for graceful shutdown (old workaround) | `fn.Run(ctx, ...)` with a signal-aware ctx already drains |
| Multiple NATS connections per process | Construct one `*nats.Conn` at startup, share |
| Config tunables read via `os.Getenv` | Use `BOOST_BOOTSTRAP_FUNCTION_ADAPTER_NATS_*` overrides |
