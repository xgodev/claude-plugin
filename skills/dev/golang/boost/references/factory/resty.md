**REQUIRED BACKGROUND:**
- `references/start.md` — `boost.Start()` first.
- `references/wrapper/config.md` — config namespacing semantics.

## Construction — one client per upstream

```go
import "github.com/xgodev/boost/factory/contrib/go-resty/resty/v2"

func init() {
    resty.ConfigAdd("boost.factory.resty.customer")
    resty.ConfigAdd("boost.factory.resty.janis")
}

func main() {
    boost.Start()
    ctx := context.Background()

    customerHTTP, err := resty.NewClientWithConfigPath(ctx, "boost.factory.resty.customer")
    if err != nil { log.Fatalf("customer http: %v", err) }

    janisHTTP, err := resty.NewClientWithConfigPath(ctx, "boost.factory.resty.janis")
    if err != nil { log.Fatalf("janis http: %v", err) }

    // ... pass into your domain services ...
}
```

Each upstream gets its own config root, registered in `init()` via `resty.ConfigAdd("boost.factory.resty.<target>")`. The boot banner then enumerates timeouts, retries, base URL, etc., per target. Operators override via `BOOST_FACTORY_RESTY_CUSTOMER_*` / `BOOST_FACTORY_RESTY_JANIS_*`.

## Per-target tunables (under each `boost.factory.resty.<target>` root)

Standard knobs registered automatically:

| Key suffix | What |
|---|---|
| `.baseURL` | Base URL for every request |
| `.timeout` | Per-request timeout (`time.Duration`) |
| `.retryCount` | Retry budget |
| `.retryWaitTime` | Base backoff between retries |

Application-specific extras (auth header, client ID, etc.) typically live in your own service config, not `boost.factory.resty.*` — pass them explicitly to your client constructor.

## Observability plugins

The constructors also accept `plugins ...Plugin` — if the service uses one of these vendors, add the matching plugin here instead of hand-instrumenting each call site:

| Vendor | Import | Usage |
|---|---|---|
| Datadog | `.../factory/contrib/go-resty/resty/v2/plugins/contrib/datadog/dd-trace-go/v1` | `resty.NewClientWithConfigPath(ctx, path, dd.NewDatadog(opts...).Register)` |
| OpenTelemetry | `.../factory/contrib/go-resty/resty/v2/plugins/contrib/dubonzi/otelresty/v1` | `..., otel.NewOtelresty(opts...).Register)` |
| Prometheus | `.../factory/contrib/go-resty/resty/v2/plugins/contrib/prometheus/client_golang/v1` | `..., prom.NewPrometheusWithOptions(opts).Register)` |

## Other plugins

| Plugin | Import | Usage | What it does |
|---|---|---|---|
| Request ID | `.../factory/contrib/go-resty/resty/v2/plugins/extra/requestid` | `resty.NewClientWithConfigPath(ctx, path, reqid.NewRequestID().Register)` | Injects `X-Request-ID` into every outbound request |
| Retry | `.../factory/contrib/go-resty/resty/v2/plugins/extra/retry` | `..., retry.NewRetry().Register)` | Exponential backoff retry on 429/5xx/timeout |

## Red flags

| Red flag | Fix |
|---|---|
| `resty.New()` directly from the upstream SDK | Use `resty.NewClientWithConfigPath(ctx, "boost.factory.resty.<target>")` |
| Single `resty.NewClient` shared across multiple upstreams | One client per upstream, each with its own config root |
| Config root not registered via `resty.ConfigAdd` in `init()` | Register so the boot banner discovers the target |
| Hard-coded base URL or timeout in the client constructor | Tune via `boost.factory.resty.<target>.baseURL` / `.timeout` |
| Reading API keys / auth headers via `os.Getenv` | Register them as `myapp.<target>.apiKey` via `config.Add` (see `references/wrapper/config.md`) |
