**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`, `references/factory/gcp-api.md`, `references/factory/gcp-grpc.md`.

```go
import bq "github.com/xgodev/boost/factory/contrib/cloud.google.com/bigquery/v1"

client, err := bq.NewClient(ctx)
if err != nil { log.Fatalf("bigquery: %v", err) }
defer client.Close()
```

Configure under `boost.factory.gcp.bigquery.*`. The factory composes nested `boost.factory.gcp.bigquery.apiOptions.*` (GCP credentials, endpoint) and `boost.factory.gcp.bigquery.grpcOptions.*` (keepalive, retries, message size). Override individually:

```
BOOST_FACTORY_GCP_BIGQUERY_APIOPTIONS_PROJECTID=my-project
BOOST_FACTORY_GCP_BIGQUERY_GRPCOPTIONS_KEEPALIVE_TIME=30s
```

`plugins ...clientgrpc.Plugin` accepts gRPC interceptors (tracing, metrics).

## Red flags

| Red flag | Fix |
|---|---|
| `bigquery.NewClient(ctx, projectID)` from upstream SDK directly | `bq.NewClient(ctx)` |
| `GOOGLE_CLOUD_PROJECT` via `os.Getenv` | `BOOST_FACTORY_GCP_BIGQUERY_APIOPTIONS_PROJECTID` |
| Forgetting `defer client.Close()` | Add it — drains gRPC |
