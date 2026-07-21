**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. For event-handler integration (CloudEvents + middleware chain) -> `references/bootstrap/adapter-kafka.md`.

## Canonical examples (ship with boost)

- `factory/contrib/confluentinc/confluent-kafka-go/v2/examples/producer/main.go`
- `factory/contrib/confluentinc/confluent-kafka-go/v2/examples/consumer/main.go`

## Construction

```go
import kafkafact "github.com/xgodev/boost/factory/contrib/confluentinc/confluent-kafka-go/v2"

producer, err := kafkafact.NewProducer(ctx)
consumer, err := kafkafact.NewConsumer(ctx)
```

Configure brokers (`.brokers`), consumer group id (`.consumer.groupId`), security protocol (`.consumer.protocol`), producer (`.producer.*`) and log (`.log.*`) under `boost.factory.confluent.*` (override `BOOST_FACTORY_CONFLUENT_*`).

## Factory vs adapter

| Use case | Reach for |
|---|---|
| Custom Kafka pipeline (low-level Poll, manual offset commit) | `references/factory/kafka.md` (raw client) |
| Event handler over CloudEvents semantics with middleware chain | `references/bootstrap/adapter-kafka.md` |

## Red flags

| Red flag | Fix |
|---|---|
| `kafka.NewProducer(&kafka.ConfigMap{...})` directly | `kafkafact.NewProducer(ctx)` |
| Brokers/groupID via `os.Getenv` | `BOOST_FACTORY_CONFLUENT_*` |
| Forgetting `producer.Close()` / `consumer.Close()` on shutdown | Add it |
