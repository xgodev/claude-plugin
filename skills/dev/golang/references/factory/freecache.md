**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. For typed cache abstraction → `references/wrapper/cache.md`.

```go
import freecachefact "github.com/xgodev/boost/factory/contrib/coocood/freecache/v1"

c, err := freecachefact.NewCache(ctx)
if err != nil { log.Fatalf("freecache: %v", err) }
```

Configure size (in bytes) under `boost.factory.freecache.size` (override `BOOST_FACTORY_FREECACHE_SIZE`). Once full, freecache evicts oldest entries — predictable memory ceiling.

## bigcache vs freecache

| Pick | When |
|---|---|
| bigcache | Tunable shard count, large entries; lifetime-based eviction |
| freecache | Strict memory cap; LRU eviction; simpler config |

Both are GC-friendly. Pick whichever a sibling service in your monorepo already uses.

## Red flags

| Red flag | Fix |
|---|---|
| `freecache.NewCache(size)` directly | `freecachefact.NewCache(ctx)` |
| Mixing freecache and bigcache in the same binary | Pick one |
| Used for shared state across replicas | Per-process; use Redis |
