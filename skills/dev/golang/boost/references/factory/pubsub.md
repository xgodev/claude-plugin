**REQUIRED BACKGROUND:**
- `references/start.md` -- `boost.Start()` first.
- `references/wrapper/config.md` -- project ID is read from config, not `os.Getenv`.

## Construction

```go
import fpubsub "github.com/xgodev/boost/factory/contrib/cloud.google.com/pubsub/v2"

pb, err := fpubsub.NewClient(ctx)
if err != nil { log.Fatalf("pubsub client: %v", err) }
defer pb.Close()
```

The client reads its project ID and connection options from boost config (`boost.factory.gcp.pubsub.apiOptions.projectId` and friends). Override at deploy via `BOOST_FACTORY_GCP_PUBSUB_APIOPTIONS_PROJECTID=...`.

## Version -- v2 is the default

New code uses v2 (`cloud.google.com/go/pubsub/v2`): `pb.Publisher(topic)` / `pb.Subscriber(sub)` send and receive, `pb.TopicAdminClient` / `pb.SubscriptionAdminClient` create resources. The v1 factory stays only for apps that pin it.

The fx modules pick the version by config, each key `v2` by default:

| Key | Selects |
|---|---|
| `boost.factory.gcp.pubsub.version` | the `*pubsub.Client` module |
| `boost.wrapper.publisher.driver.pubsub.version` | the publisher driver module |
| `boost.bootstrap.function.adapter.pubsub.version` | the `@Function` adapter module |

Staying on v1 means setting the three keys to `v1` -- one left at `v2` puts a v2 driver or adapter next to a v1 client. Any other value fails the boot with an error naming the key.

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
| Forgetting `defer pb.Close()` | Add it -- graceful gRPC shutdown |
| Constructing two clients (one for publish, one for subscribe) | Construct one, share it |
| New code importing `.../pubsub/v1` or `cloud.google.com/go/pubsub` (v1 SDK) | Import `.../pubsub/v2` and `cloud.google.com/go/pubsub/v2` |
| Some of the three `version` keys set to `v1`, others left at the default | Set all three to the same version |
