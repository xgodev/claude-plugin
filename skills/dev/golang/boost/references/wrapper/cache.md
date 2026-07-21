**REQUIRED BACKGROUND:**
- `references/start.md` -- `boost.Start()` first.
- `references/wrapper/config.md` -- driver config keys.

## Construct via the Manager + driver + codec

```go
import (
    "github.com/xgodev/boost/wrapper/cache"
    jsoncodec "github.com/xgodev/boost/wrapper/cache/codec/json"
    redisdrv "github.com/xgodev/boost/wrapper/cache/driver/contrib/redis/go-redis/v9"
)

// TTL is a DRIVER option, set once at construction -- not a per-call argument.
drv := redisdrv.NewClient(redisClient, &redisdrv.Options{TTL: 5 * time.Minute})

// NewManager(name, codec, drivers...) -- the name labels metrics/plugins.
mgr := cache.NewManager[Order]("orders", jsoncodec.New[Order](), drv)

// later
err := mgr.Set(ctx, "orders/"+id, order)                  // opts ...cache.OptionSet, no TTL
ok, order, err := mgr.Get(ctx, "orders/"+id)              // THREE values: found?, value, error
err = mgr.Del(ctx, "orders/"+id)
```

`Manager[T]` is generic over the value type. The codec decides serialization (`json`, `gob`, `binary`, `string`); the driver decides storage backend. `Set` takes variadic `cache.OptionSet` (`cache.SaveEmpty()`, `cache.AsyncSave()`, `cache.WithoutReplicate()`) -- none of them is a TTL.

## Available drivers (out of the box)

| Driver | Path |
|---|---|
| Redis (go-redis client) | `wrapper/cache/driver/contrib/redis/go-redis/v9` -- `NewClient(*redis.Client, *Options)` |
| Redis cluster (go-redis client) | `wrapper/cache/driver/contrib/redis/go-redis/v9` -- `NewCluster(*redis.ClusterClient, *Options)` |
| allegro/bigcache | `wrapper/cache/driver/contrib/allegro/...` |
| stretchr testify in-memory | `wrapper/cache/driver/contrib/stretchr/...` (test scaffolding) |

Drivers register **no** config keys -- there is no `config.Add` anywhere under `wrapper/cache`. Tuning (TTL, ...) is a struct literal passed to the driver constructor; wire it from your own `config.Add` keys if it must be deployable.

## Codec selection

| Codec | When |
|---|---|
| `codec/json` | Default for structs, human-debuggable in `redis-cli` |
| `codec/gob` | Faster + smaller for Go-only consumers |
| `codec/binary` | When the value type is `[]byte` (no transformation) |
| `codec/string` | When the value type is `string` (no transformation) |

## Plugin chain (cross-cutting concerns)

Wrap the Manager with plugins for metrics, logging, TTL enforcement, etc. (see `wrapper/cache/plugins/`). Plugins compose like middleware -- outer plugins see calls before the driver does.

## Red flags

| Red flag | Fix |
|---|---|
| `redis.Client.Set(...)` / `Get(...)` directly from the upstream SDK | Wrap behind `cache.Manager[T]` + a driver |
| Per-call codec selection (instantiating a new codec for each `Set`) | Construct the codec once at startup |
| Mixing codecs across reads and writes for the same key (e.g., wrote with `gob`, reading with `json`) | Pick one codec per Manager |
| Reading Redis URL via `os.Getenv` | Register your own key with `config.Add` (see `references/wrapper/config.md`), build the `*redis.Client` from it, pass it to `NewClient` |
| Treating a `Get` miss as an error (`cache.ErrNotFound`) | No such symbol exists -- a miss is `ok == false` with a **nil** error; branch on the first return value |
