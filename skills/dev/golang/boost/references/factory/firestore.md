**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`, `references/factory/gcp-api.md`, `references/factory/gcp-grpc.md`.

```go
import fs "github.com/xgodev/boost/factory/contrib/cloud.google.com/firestore/v1"

client, err := fs.NewClient(ctx)
if err != nil { log.Fatalf("firestore: %v", err) }
defer client.Close()
```

Configure under `boost.factory.gcp.firestore.*`. Composes `apiOptions.*` (GCP credentials, endpoint) + `grpcOptions.*` (keepalive, retries). Override at deploy via `BOOST_FACTORY_GCP_FIRESTORE_*`. `plugins ...clientgrpc.Plugin` accepts gRPC interceptors.

## Red flags

| Red flag | Fix |
|---|---|
| `firestore.NewClient(ctx, projectID)` from upstream SDK directly | `fs.NewClient(ctx)` |
| `GOOGLE_CLOUD_PROJECT` via `os.Getenv` | `BOOST_FACTORY_GCP_FIRESTORE_APIOPTIONS_PROJECTID` |
| Forgetting `defer client.Close()` | Add it |
