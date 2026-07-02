**REQUIRED BACKGROUND:**
- `references/start.md` — `boost.Start()` first.
- `references/wrapper/config.md` — project ID is read from config, not `os.Getenv`.

## Construction

```go
import fpubsub "github.com/xgodev/boost/factory/contrib/cloud.google.com/pubsub/v1"

pb, err := fpubsub.NewClient(ctx)
if err != nil { log.Fatalf("pubsub client: %v", err) }
defer pb.Close()
```

The client reads its project ID and connection options from boost config (`boost.factory.gcp.pubsub.apiOptions.projectId` and friends). Override at deploy via `BOOST_FACTORY_GCP_PUBSUB_APIOPTIONS_PROJECTID=...`.

## Lifecycle

The same `*pubsub.Client` typically feeds both:
- A publisher driver (see `references/wrapper/publisher.md`)
- A subscriber adapter (see `references/bootstrap/adapter-pubsub.md`)

Construct once, share, and `defer pb.Close()` so the gRPC connection drains on shutdown.

## Red flags

| Red flag | Fix |
|---|---|
| `pubsub.NewClient(ctx, projectID)` directly from the upstream SDK | Use `fpubsub.NewClient(ctx)` so config + observability instrumentation are wired |
| Reading `GOOGLE_CLOUD_PROJECT` via `os.Getenv` | Use `BOOST_FACTORY_GCP_PUBSUB_APIOPTIONS_PROJECTID` (or override the koanf key) |
| Forgetting `defer pb.Close()` | Add it — graceful gRPC shutdown |
| Constructing two clients (one for publish, one for subscribe) | Construct one, share it |
