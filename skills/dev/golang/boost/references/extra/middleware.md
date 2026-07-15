**REQUIRED BACKGROUND:**
- `references/bootstrap/middleware.md` — the middlewares this skill composes.
- `references/bootstrap/adapter-pubsub.md` — the canonical reason this skill is reached for (production workaround).

## What it is

`extra/middleware.NewAnyErrorWrapper[T](ctx, name, ...mws)` is the generic chain composer. It returns a wrapper that you can apply to any handler typed compatibly. `fn.Run` uses it internally; you reach for it directly only when you can't use `fn.Run` (e.g., the documented Pub/Sub adapter workaround).

## Usage

```go
import (
    "github.com/xgodev/boost/extra/middleware"
    "github.com/xgodev/boost/bootstrap/function"
)

wrp := middleware.NewAnyErrorWrapper[*cloudevents.Event](
    ctx, "bootstrap", rec, lmi, pmi,
)

wrappedHandler := function.Wrapper[*cloudevents.Event](wrp, handle)

// then drive wrappedHandler manually (e.g., apubsub.NewSubscriber)
```

The middleware order arguments here mirror the order semantics from `references/bootstrap/middleware.md`: outermost-to-innermost is `rec, lmi, pmi`.

## When to use

- The Pub/Sub / NATS / Kafka adapter workaround for ctx-loss (see `references/bootstrap/adapter-pubsub.md`).
- Custom drivers / adapters where you need the same chain semantics outside `fn.Run`.

**Don't use** when the canonical `function.New + fn.Run` works — `fn.Run` already calls this internally with the right arguments.

## Observability / resilience plugins for this chain

These are separate `AnyErrorMiddleware`/`AnyMiddleware`/`ErrorMiddleware` implementations you add as extra arguments to `NewAnyErrorWrapper` (or the `Any`/`Error` variants) — not the per-factory `plugins ...Plugin` pattern used by `factory/*` constructors, a different plugin system with the same name:

| Vendor | Import | Usage |
|---|---|---|
| Hystrix (circuit breaker) | `.../extra/middleware/plugins/contrib/afex/hystrix-go/v0` | `middleware.NewAnyErrorWrapper(ctx, "name", hystrix.NewAnyErrorMiddleware(ctx, "circuit-name"))` |
| Datadog | `.../extra/middleware/plugins/contrib/datadog/dd-trace-go/v1` | `middleware.NewAnyErrorWrapper(ctx, "name", datadog.NewAnyErrorMiddleware(ctx, "span-name", "web"))` |
| Prometheus | `.../extra/middleware/plugins/contrib/prometheus/client_golang/v1` | `middleware.NewAnyErrorWrapper(ctx, "name", prometheus.NewAnyErrorMiddleware(ctx))` |
| Fallback (no-op passthrough) | `.../extra/middleware/plugins/native/fallback` | `middleware.NewAnyErrorWrapper(ctx, "name", fallback.NewAnyErrorMiddleware[Result]())` — a stub middleware that delegates unchanged; useful as a placeholder slot in a chain built conditionally |

## Red flags

| Red flag | Fix |
|---|---|
| Used in place of `fn.Run` without a `// TODO(boost-upstream):` comment explaining why | Either add the comment + tracking issue, or use `fn.Run` |
| Different `T` parameter than the rest of the chain | All on `*cloudevents.Event` |
| Custom middleware order that breaks the recovery-outermost rule | Mirror `references/bootstrap/middleware.md`'s canonical order |
