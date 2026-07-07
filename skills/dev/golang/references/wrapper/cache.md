**REQUIRED BACKGROUND:**
- `references/start.md` — `boost.Start()` first.
- `references/wrapper/config.md` — driver config keys.

## Construct via the Manager + driver + codec

```go
import (
    "github.com/xgodev/boost/wrapper/cache"
    redisdrv "github.com/xgodev/boost/wrapper/cache/driver/contrib/redis/go-redis/v9"
    "github.com/xgodev/boost/wrapper/cache/codec/json"
)

drv, err := redisdrv.New(ctx, redisClient)
if err != nil { log.Fatalf("cache driver: %v", err) }

mgr := cache.NewManager[Order](drv, json.New[Order]())

// later
err := mgr.Set(ctx, "orders/"+id, order, 5*time.Minute)
order, err := mgr.Get(ctx, "orders/"+id)
err = mgr.Del(ctx, "orders/"+id)
```

`Manager[T]` is generic over the value type. The codec decides serialization (`json`, `gob`, `binary`, `string`); the driver decides storage backend.

## Available drivers (out of the box)

| Driver | Path |
|---|---|
| Redis (go-redis client) | `wrapper/cache/driver/contrib/redis/go-redis/v9` |
| Redis cluster (go-redis client) | `wrapper/cache/driver/contrib/redis/go-redis/v9` (cluster_driver.go) |
| allegro/bigcache | `wrapper/cache/driver/contrib/allegro/...` |
| stretchr testify in-memory | `wrapper/cache/driver/contrib/stretchr/...` (test scaffolding) |

Each driver has its own config root under `boost.wrapper.cache.driver.<vendor>.<lib>.*`.

## Codec selection

| Codec | When |
|---|---|
| `codec/json` | Default for structs, human-debuggable in `redis-cli` |
| `codec/gob` | Faster + smaller for Go-only consumers |
| `codec/binary` | When the value type is `[]byte` (no transformation) |
| `codec/string` | When the value type is `string` (no transformation) |

## Plugin chain (cross-cutting concerns)

Wrap the Manager with plugins for metrics, logging, TTL enforcement, etc. (see `wrapper/cache/plugins/`). Plugins compose like middleware — outer plugins see calls before the driver does.

## Red flags

| Red flag | Fix |
|---|---|
| `redis.Client.Set(...)` / `Get(...)` directly from the upstream SDK | Wrap behind `cache.Manager[T]` + a driver |
| Per-call codec selection (instantiating a new codec for each `Set`) | Construct the codec once at startup |
| Mixing codecs across reads and writes for the same key (e.g., wrote with `gob`, reading with `json`) | Pick one codec per Manager |
| Reading Redis URL via `os.Getenv` | Use `BOOST_WRAPPER_CACHE_DRIVER_REDIS_GOREDIS_*` config keys |
| Expecting cache `Get` miss to return zero-value silently | Driver typically returns a typed `cache.ErrNotFound`; check it explicitly |
