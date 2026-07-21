**REQUIRED BACKGROUND:** `references/start.md`. For middleware -> `references/bootstrap/middleware.md`. For Pub/Sub adapter specifics (incl. ctx-loss workaround) -> `references/bootstrap/adapter-pubsub.md`.

## Iron Law -- handler signature is forced by `function.Handler[T]`

The framework declares (`bootstrap/function/handler.go`):

```go
type Handler[T any] func(context.Context, cloudevents.Event) (T, error)
```

Input is **always** `cloudevents.Event` by value. The return must be a pointer or a slice of pointers: `function.New[T]` type-switches on `case []*event.Event, *event.Event:` and returns `errors.New("unsupported handler type")` for anything else (`bootstrap/function/function.go:22-30`). Both legal forms are handled by the logger and publisher middlewares, which fan out the slice case (`middleware/logger/logger.go:51`, `middleware/publisher/publisher.go:29`).

```go
// CORRECT -- single event
func handle(ctx context.Context, in cloudevents.Event) (*cloudevents.Event, error)

// CORRECT -- batch
func handle(ctx context.Context, in cloudevents.Event) ([]*cloudevents.Event, error)

// WRONG -- function.New returns errors.New("unsupported handler type")
func handle(ctx context.Context, in cloudevents.Event) (cloudevents.Event, error)

// WRONG -- does not compile against function.Handler[*cloudevents.Event]
func handle(ctx context.Context, in *cloudevents.Event) (*cloudevents.Event, error)
```

## Wiring

```go
import (
    "github.com/xgodev/boost"
    "github.com/xgodev/boost/bootstrap/function"
    cloudevents "github.com/cloudevents/sdk-go/v2"
)

func main() {
    boost.Start()
    ctx := context.Background()

    // ... build middlewares (see boost-bootstrap-middleware) ...
    // ... build adapter (see boost-bootstrap-adapter-pubsub or analogous) ...

    fn, err := function.New[*cloudevents.Event](rec, lmi, pmi)
    if err != nil { log.Fatalf("function: %v", err) }

    if err := fn.Run(ctx, handle, adapter); err != nil {
        log.Fatalf("run: %v", err)
    }
}
```

The whole chain must agree on one `T` (here `*cloudevents.Event`): `function.New[*cloudevents.Event](...)`, `lm.NewAnyErrorMiddleware[*cloudevents.Event]()`, `apubsub.New[*cloudevents.Event](pb)`. Mixing `T` types yields cryptic compile errors at the wiring call.

## Red flags

| Red flag | Fix |
|---|---|
| Handler returning `cloudevents.Event` (value) | Change return to `*cloudevents.Event` (or `[]*cloudevents.Event`) |
| Handler with input `*cloudevents.Event` (pointer) | Change to value -- framework signature is forced |
| `function.New[cloudevents.Event](...)` (T = value) | Change to `*cloudevents.Event` or `[]*cloudevents.Event` -- anything else is a constructor error |
| One middleware in the chain parameterized differently from the rest | Pick one `T` and use it everywhere |

**Verification by example:** before claiming a handler signature is correct, grep `bootstrap/function/handler.go` and confirm the actual `Handler[T]` type signature. The framework is the source of truth; this skill can drift.
