**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

## Canonical examples (ship with boost)

- `factory/contrib/elastic/go-elasticsearch/v8/examples/connect/main.go`
- `factory/contrib/elastic/go-elasticsearch/v8/examples/health/main.go`

The `health` example is the reference for wiring this factory into `references/extra/health.md` checkers.

## Client

```go
import esfact "github.com/xgodev/boost/factory/contrib/elastic/go-elasticsearch/v8"

es, err := esfact.NewClient(ctx)
if err != nil { log.Fatalf("elasticsearch: %v", err) }
```

Configure addresses, auth, transport TLS under `boost.factory.elasticsearch.*` (override `BOOST_FACTORY_ELASTICSEARCH_*`).

## Bulk indexer (high-throughput ingest)

```go
bi, err := esfact.NewBulkIndexer(ctx, es)
if err != nil { log.Fatalf("es bulk: %v", err) }
defer bi.Close(ctx)

bi.Add(ctx, esutil.BulkIndexerItem{Action: "index", Index: "orders", Body: strings.NewReader(jsonBody)})
```

Tune flush size + interval via `boost.factory.elasticsearch.bulk.*`.

## Red flags

| Red flag | Fix |
|---|---|
| `elasticsearch.NewClient(esCfg)` directly | `esfact.NewClient(ctx)` |
| Per-document `es.Index` calls in a hot path | Use `BulkIndexer` — orders of magnitude faster |
| Forgetting `defer bi.Close(ctx)` | Add it — flushes pending batches |
