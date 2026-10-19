**REQUIRED BACKGROUND:** `references/start.md`. For function deadletter integration -> `references/bootstrap/middleware.md`. For adding a new driver to boost -> `references/CONTRIBUTING.md`.

In a builder app (every new app) do not build it by hand: `@Inject` a `*publisher.Publisher` and the generator builds it, the driver chosen by `boost.wrapper.publisher.driver.name`, `drivers=[nats, pubsub]` to generate only those, `name=orders` for a publisher on the `orders` clients (`references/builder.md`).

## Construct via the driver-agnostic wrapper

```go
import (
    "github.com/xgodev/boost/wrapper/publisher"
    drvpubsub "github.com/xgodev/boost/wrapper/publisher/driver/contrib/cloud.google.com/pubsub/v2"
)

drv, err := drvpubsub.New(ctx, pb)   // pb is *pubsub.Client (see boost-factory-pubsub)
if err != nil { log.Fatalf("publisher driver: %v", err) }

pub := publisher.New(drv)
```

`publisher.New(driver)` returns a `Publisher` that consumers -- including the function publisher middleware -- depend on. Driver swaps don't require call-site changes.

## Available drivers (out of the box)

| Driver | Path |
|---|---|
| Google Cloud Pub/Sub | `wrapper/publisher/driver/contrib/cloud.google.com/pubsub/v2` (`v1` for apps pinned to it -- `references/factory/pubsub.md`) |
| Confluent Kafka | `wrapper/publisher/driver/contrib/confluentinc/confluent-kafka-go/v2` |
| NATS | `wrapper/publisher/driver/contrib/nats-io/nats.go/v1` |
| Lovoo Goka | `wrapper/publisher/driver/contrib/lovoo/goka/v1` |

## Errors

`pub.Publish(ctx, events)` returns an error when the driver fails or when any event fails: one `Internal` error joining every failed event's error, tagged with its event ID -- `errors.Is`/`errors.As` still reach each cause. Never read `[]PublishOutput` to find a failure the error already carries. Middlewares (prometheus) still receive the per-event outputs with a nil chain error; the aggregate is built after the chain.

The Kafka driver (`confluentinc/confluent-kafka-go/v2`) returns only after every message has its delivery report, bounded by the `ctx` given to `Publish`: a failed delivery (`TopicPartition.Error`) or a `ctx` that ends first becomes that event's error. The reports go to a channel per `Publish` call, so they no longer reach the producer's `Events()` channel. Give `Publish` a context with a deadline.

## Republishing inside a function handler

Wire `pub` into the function publisher middleware (see `references/bootstrap/middleware.md`):

```go
pmi, _ := pm.NewAnyErrorMiddleware[*cloudevents.Event](pub)
```

The middleware fires on a handler's successful return -- the returned `*cloudevents.Event` gets published via the wrapped driver. The handler does NOT call `pub.Publish` manually; that bypasses middleware bookkeeping (deadletter, ordering, instrumentation).

## Topic selection

The driver typically uses the event's `Subject()` to route:

| Driver | What `Subject()` means |
|---|---|
| GCP Pub/Sub | Topic ID |
| Kafka | Topic |
| NATS | Subject |
| SNS (if added) | Full ARN -- see `references/CONTRIBUTING.md` for the extrapolation discipline |

Set the destination via `out.SetSubject("topic-name")` before returning from the handler.

## Red flags

| Red flag | Fix |
|---|---|
| Calling `pb.Publisher("foo").Publish(ctx, ...)` directly inside a handler | Return `*cloudevents.Event` from the handler; let the publisher middleware drive `pub.Publish` |
| `err == nil` read as "every event published", or failures dug out of `[]PublishOutput` | `Publish` returns the joined per-event error; check it |
| Waiting for Kafka delivery on the producer's `Events()` channel | `Publish` already waits for each report, bounded by its `ctx` |
| Building a publisher per request instead of once at startup | Construct `pub` in `main`, pass to handlers via deps |
| Using a third-party publisher abstraction in parallel | Use `wrapper/publisher` as the only abstraction so middleware sees everything |
