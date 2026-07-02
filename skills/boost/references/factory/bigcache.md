**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. For typed cache abstraction over multiple backends → `references/wrapper/cache.md`.

```go
import bigcachefact "github.com/xgodev/boost/factory/contrib/allegro/bigcache/v3"

c, err := bigcachefact.NewCache(ctx)
if err != nil { log.Fatalf("bigcache: %v", err) }
```

Configure shards, lifetime, max entry size under `boost.factory.bigcache.*` (override `BOOST_FACTORY_BIGCACHE_*`).

## Why bigcache vs sync.Map / a Go map

bigcache stores entries off-heap so the GC doesn't scan them — material when entry count > 100k. For typed access with codecs, prefer `references/wrapper/cache.md` with the bigcache driver.

## Red flags

| Red flag | Fix |
|---|---|
| `bigcache.New(...)` directly | `bigcachefact.NewCache(ctx)` |
| Tunables hardcoded | `BOOST_FACTORY_BIGCACHE_*` |
| Used for shared state across replicas | bigcache is per-process; use Redis |
