**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import hystrixfact "github.com/xgodev/boost/factory/contrib/afex/hystrix-go/v0"
import "github.com/afex/hystrix-go/hystrix"

func init() {
    hystrixfact.CommandConfigAdd("customer-api")
    hystrixfact.CommandConfigAdd("janis-api")
}

err := hystrix.Do("customer-api", func() error {
    return customerHTTP.Get("/customers/123")
}, nil)
```

Each `CommandConfigAdd("<name>")` registers `boost.factory.hystrix.<name>.*` keys: `timeout`, `maxConcurrentRequests`, `errorPercentThreshold`, `sleepWindow`, `requestVolumeThreshold`. Override at deploy via `BOOST_FACTORY_HYSTRIX_<NAME>_*`.

## Per-upstream commands

One command name per upstream (CustomerAPI, Janis, Pricing, ...). Sharing collapses their failure budgets — you can't isolate one bad upstream from the others.

## Observability plugin

Only Prometheus has a plugin here (no Datadog, no OTel):

| Vendor | Import | Usage |
|---|---|---|
| Prometheus | `.../factory/contrib/afex/hystrix-go/v0/plugins/extra/prometheus` | `prometheus.NewPrometheus().Register(ctx)` — registered directly, not passed as a factory constructor arg |

## Red flags

| Red flag | Fix |
|---|---|
| Single global command for all outbound calls | Per-upstream commands via `CommandConfigAdd` |
| `hystrix.ConfigureCommand("name", ...)` from upstream API directly | Configure via `BOOST_FACTORY_HYSTRIX_<NAME>_*` so it shows in the boot banner |
| Circuit breaker around in-process function calls | Use it at the outbound HTTP / RPC boundary; in-process calls don't need it |
