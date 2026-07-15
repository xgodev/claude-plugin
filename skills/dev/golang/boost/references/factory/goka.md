**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. For raw Kafka producer/consumer → `references/factory/kafka.md`.

```go
import gokafact "github.com/xgodev/boost/factory/contrib/lovoo/goka/v1"

emitter, err := gokafact.NewEmitter(ctx)
if err != nil { log.Fatalf("goka: %v", err) }
defer emitter.Finish()
```

Configure brokers, stream name, codec under `boost.factory.goka.*` (override `BOOST_FACTORY_GOKA_*`).

## Goka vs raw Kafka

Goka adds stream-processing semantics (key/value tables, joins, group processors) on top of Kafka. Use Goka when your service participates in a Goka topology; use raw Kafka (`references/factory/kafka.md`) when you just need produce/consume.

The publisher driver `wrapper/publisher/driver/contrib/lovoo/goka/v1` (see `references/wrapper/publisher.md`) wraps this emitter for the function publisher middleware path.

## Red flags

| Red flag | Fix |
|---|---|
| `goka.NewEmitter(...)` directly | `gokafact.NewEmitter(ctx)` |
| Brokers via `os.Getenv` | `BOOST_FACTORY_GOKA_*` |
| Forgetting `emitter.Finish()` on shutdown | Add it — flushes pending writes |
