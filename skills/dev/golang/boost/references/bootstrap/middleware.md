**REQUIRED BACKGROUND:**
- `references/bootstrap/function.md` -- generic typing rule (`T = *cloudevents.Event`).
- `references/model-errors.md` -- error types matched by deadletter mode.
- `references/wrapper/publisher.md` -- provides the publisher consumed by the publisher middleware.

## Canonical chain

```
recovery -> logger -> publisher
```

```go
import (
    rm "github.com/xgodev/boost/bootstrap/function/middleware/recovery"
    lm "github.com/xgodev/boost/bootstrap/function/middleware/logger"
    pm "github.com/xgodev/boost/bootstrap/function/middleware/publisher"
)

rec := rm.NewRecovery[*cloudevents.Event]()
lmi, _ := lm.NewAnyErrorMiddleware[*cloudevents.Event]()
pmi, _ := pm.NewAnyErrorMiddleware[*cloudevents.Event](pub)

// fn.Run path:
fn, _ := function.New[*cloudevents.Event](rec, lmi, pmi)

// Workaround path (see boost-bootstrap-adapter-pubsub):
wrp := middleware.NewAnyErrorWrapper[*cloudevents.Event](ctx, "bootstrap", rec, lmi, pmi)
```

## Why this order

| Layer | Position | Reason |
|---|---|---|
| `recovery` | Outermost | A panic in the handler must not kill the worker before the logger gets the error |
| `logger` | Middle | Sees both raw handler errors AND post-recovery errors; structured fields propagate |
| `publisher` | Innermost | Fires on the handler's successful result; with deadletter config, also routes errors by type |

Reordering is a footgun: putting `recovery` innermost means a panic short-circuits before the logger; putting `publisher` outermost means it fires before the handler ran.

## Returning errors for deadletter routing

In deadletter mode the publisher middleware walks the error chain with `stderrors.Unwrap` and matches each link's `%T` name against the configured list (`middleware/publisher/publisher.go:99-113`). There is exactly ONE deadletter subject (`...publisher.deadletter.subject`, `middleware/publisher/config.go:14`, applied at `publisher.go:53,65`) -- not a topic per error type. The default matched list is `[]string{"internal"}` (`config.go:21`), so `Internalf` is the default deadletter class and `NotValidf` is not routed unless you add `"notvalid"` to `...publisher.deadletter.errors`.

Return the typed error **directly**:

```go
// Matched by the default list -> published to the deadletter subject
return nil, bootsterrors.Internalf("downstream call failed")

// Not in the default list -> propagated to the caller, not published
return nil, bootsterrors.NotValidf("invalid event data")
```

Do NOT use `bootsterrors.Wrap(err, bootsterrors.Internalf(...))`: `Wrap` stores the typed error in `cause` and sets `previous` to the other error (`model/errors/functions.go:130-137`), while `(*Err).Unwrap()` returns `previous` (`model/errors/error.go:101-103`). The typed error is never reachable from the chain the matcher walks. `fmt.Errorf("%w", err)` is fine -- `stderrors.Unwrap` traverses it. See `references/model-errors.md`.

## `ignore_errors` middleware

Use only when you genuinely want a category of errors to silently ack the message instead of nack/retry. Stack outside the publisher (so the publisher still fires for non-ignored errors), but inside recovery (so panics still recover):

```go
rec := rm.NewRecovery[*cloudevents.Event]()
imi, _ := im.NewAnyErrorMiddleware[*cloudevents.Event]()  // ignore_errors
lmi, _ := lm.NewAnyErrorMiddleware[*cloudevents.Event]()
pmi, _ := pm.NewAnyErrorMiddleware[*cloudevents.Event](pub)

fn, _ := function.New[*cloudevents.Event](rec, imi, lmi, pmi)
```

## Red flags

| Red flag | Fix |
|---|---|
| Chain ordered `publisher -> logger -> recovery` (or any permutation that violates outermost=recovery) | Reorder to `recovery -> logger -> publisher` |
| Forgetting `recovery` middleware | Always include it -- production functions die otherwise |
| `bootsterrors.Wrap(err, bootsterrors.<Type>(...))` for deadletter routing | Return the typed error directly -- `Wrap` hides it from the matcher |
| Mixing `T = cloudevents.Event` and `T = *cloudevents.Event` across middlewares | All on `*cloudevents.Event` |
