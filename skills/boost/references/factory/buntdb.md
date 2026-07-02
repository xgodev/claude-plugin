**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Layout/trio convention → `references/CONTRIBUTING.md`.

```go
import buntdb "github.com/xgodev/boost/factory/contrib/tidwall/buntdb/v1"

db, err := buntdb.NewDB(ctx)
if err != nil { log.Fatalf("buntdb: %v", err) }
defer db.Close()
```

Configure path, sync mode, auto-shrink under `boost.factory.buntdb.*` (override `BOOST_FACTORY_BUNTDB_*`). Use `:memory:` for pure in-memory.

## When to reach for buntdb

- Local cache for derived data that's cheap to recompute on cold start.
- Test/fixture KV that you don't want to spin up Redis for.
- Sidecar state for a worker (rate limit counters, circuit-breaker state).

For shared state across replicas, **don't use buntdb** — it's per-process. Use `references/wrapper/cache.md` with a Redis driver.

## Red flags

| Red flag | Fix |
|---|---|
| `buntdb.Open(path)` with hardcoded path | `buntdb.NewDB(ctx)` + `BOOST_FACTORY_BUNTDB_PATH` |
| Sharing across replicas expecting consistency | Switch to Redis via `references/wrapper/cache.md` |
| Forgetting `defer db.Close()` | Add it |
