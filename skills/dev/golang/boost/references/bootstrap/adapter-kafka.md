**REQUIRED BACKGROUND:**
- `references/bootstrap/function.md` -- handler typing rule.
- `references/bootstrap/middleware.md` -- recovery/logger/publisher chain.
- `references/extra/middleware.md` -- `NewAnyErrorWrapper` for the workaround.
- `references/bootstrap/adapter-pubsub.md` -- same shape, full workaround pattern documented there.

## Canonical (prototype / dev)

```go
import (
    akafka "github.com/xgodev/boost/bootstrap/function/adapter/contrib/confluentinc/confluent-kafka-go/v2"
    "github.com/xgodev/boost/bootstrap/function"
)

fn, _ := function.New[*cloudevents.Event](rec, lmi, pmi)
fn.Run(ctx, handle, akafka.New[*cloudevents.Event](consumer))
```

Two distinct namespaces (`.../confluent-kafka-go/v2/config.go`):

| Namespace | Keys |
|---|---|
| `boost.bootstrap.function.adapter.kafka_confluent.*` (adapter, `config.go:10-18`) | `topics`, `timeOut`, `manualCommit`, `maxWorkers`, `backoff`, `backoffBase`, `maxBackoff`, `retryLimit` |
| `boost.factory.confluent.*` (client, `factory/.../config.go:8,22-23,33-35`) | `brokers`, `consumer.groupId`, `consumer.autoOffsetReset`, `consumer.autoCommit`, producer settings |

Env overrides use `_` as the path separator, so factory keys map straightforwardly (`BOOST_FACTORY_CONFLUENT_BROKERS`). The literal underscore inside the `kafka_confluent` segment is NOT expressible in the env parser (`wrapper/config/contrib/knadh/koanf/v1/loader.go:214-235` splits on `_`) -- set the adapter keys in a config file.

## Production caveat -- same ctx-loss as Pub/Sub

`bootstrap/function/adapter/contrib/confluentinc/confluent-kafka-go/v2/helper.go:41` hard-codes:

```go
err := subscriber.Subscribe(context.Background())
```

Passing a signal-aware ctx does NOT restore graceful shutdown: `subscriber.go:44-67` is a bare `for {}` over `consumer.ReadMessage` that never selects on `ctx.Done()`. The ctx only reaches the handler (`subscriber.go:131`); the receive loop keeps running regardless. Bypassing `fn.Run` and building the chain via `extra/middleware.NewAnyErrorWrapper` (see `references/bootstrap/adapter-pubsub.md`) lets you propagate cancellation INTO the handler, but the subscriber loop itself only stops when the process exits. Add the `// TODO(boost-upstream):` annotation naming the offending file.

## Consumer group semantics

Kafka delivers each message to exactly one member of a consumer group. Set `boost.factory.confluent.consumer.groupId` (`factory/.../config.go:22,34`) so multiple replicas of your service share the partition load.

The **subscriber** commits, not the middleware: on a successful handler return it calls `consumer.CommitMessage(msg)` when `manualCommit` is enabled (default `true` -- `subscriber.go:151-156`, `config.go:24`). On a handler error there is no nack and no broker redelivery: `subscriber.go:131-148` retries IN PROCESS with local backoff, and once `retryLimit` is hit (default `-1` = retry forever, `config.go:29`) it breaks out and moves on WITHOUT committing. Return typed errors directly (see `references/model-errors.md`) so the deadletter middleware can route by type.

## Red flags

| Red flag | Fix |
|---|---|
| `kafka.Consumer.Poll(...)` / `ReadMessage(...)` loops directly | Use `akafka.NewSubscriber(...).Subscribe(ctx)` or `function.New + fn.Run` |
| Bypass of `fn.Run` without `// TODO(boost-upstream):` naming `helper.go:41` | Add the comment, OR accept ungraceful shutdown |
| Reading `KAFKA_BROKERS` / `KAFKA_GROUP_ID` via `os.Getenv` | Use `boost.factory.confluent.brokers` / `.consumer.groupId` |
| Manual offset commit inside the handler | The subscriber already commits on success when `manualCommit` is true (default) |
