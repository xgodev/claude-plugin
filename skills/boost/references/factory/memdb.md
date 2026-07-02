**REQUIRED BACKGROUND:** `references/start.md`.

```go
import memdbfact "github.com/xgodev/boost/factory/contrib/hashicorp/memdb/v1"
import "github.com/hashicorp/go-memdb"

schema := &memdb.DBSchema{ /* tables + indexes */ }

db, err := memdbfact.NewMemDB(ctx, schema)
if err != nil { log.Fatalf("memdb: %v", err) }
```

memdb is schema-first: define tables and indexes upfront, then run transactions. Unlike buntdb (untyped KV), memdb gives indexed lookups, typed records, and ACID transactions in-process.

## When to reach for memdb

- Service that holds a derived view of upstream data and wants indexed query semantics without a database round-trip.
- Read-mostly cache where multiple indexes matter (lookup by ID + by status + by owner).

For shared state across replicas, **don't use memdb** — it's per-process.

## Red flags

| Red flag | Fix |
|---|---|
| `memdb.NewMemDB(schema)` directly | `memdbfact.NewMemDB(ctx, schema)` |
| Defining the schema inside a request handler | Build schema once at startup |
| Sharing across replicas expecting consistency | Use a real database / Redis |
