**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

## Canonical example (ships with boost)

- `factory/contrib/gocloud.dev/pubsub/v0/examples/pubsub/main.go`

## Construction

```go
import gcppubsub "github.com/xgodev/boost/factory/contrib/gocloud.dev/pubsub/v0"

topic, err := gcppubsub.NewTopic(ctx)
if err != nil { log.Fatalf("topic: %v", err) }
defer topic.Shutdown(ctx)

sub, err := gcppubsub.NewSubscription(ctx)
defer sub.Shutdown(ctx)
```

Configure `.type` (default `memory`; valid: `sqs`, `sns`, `kafka`, `nats`, `pubsub`), `.resource` (default `topicA`) and `.region` under `boost.factory.gocloud.*` (override `BOOST_FACTORY_GOCLOUD_*`). The factory builds the provider URL from `.type` + `.resource` -- operators never supply a URL.

## When gocloud.dev vs the native factory?

| Reach for gocloud.dev | Reach for native (`references/factory/pubsub.md`, `references/factory/kafka.md`, ...) |
|---|---|
| Want to swap providers via `.type` config without code change | Committed to one provider; want full feature surface |
| Tests use the default `memory` type for in-process fakes | Production-only path; tests run against real broker |

The native factories expose more provider-specific knobs. gocloud.dev exposes the lowest-common-denominator API.

## Red flags

| Red flag | Fix |
|---|---|
| `pubsub.OpenTopic(ctx, url)` directly | `gcppubsub.NewTopic(ctx)` |
| Type/resource via `os.Getenv` | `BOOST_FACTORY_GOCLOUD_*` |
| Forgetting `defer topic.Shutdown(ctx)` | Add it |
