**REQUIRED BACKGROUND:** `references/start.md`. Mount typically via `references/factory/echo.md` or `references/extra/multiserver.md`.

The factory provides the integration glue between boost and `prometheus/client_golang` -- registries, default collectors, and the `promhttp.Handler` wrapper. Concrete API surface is mostly registration helpers; consult the source under `factory/contrib/prometheus/client_golang/v1/` for the symbols available in your boost version.

## Pattern: dedicated /metrics listener via multiserver

```go
import (
    "context"
    "net/http"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "github.com/xgodev/boost/extra/multiserver"
)

// multiserver.Server is Serve(ctx) / Shutdown(ctx) -- *http.Server does NOT satisfy it.
type metricsServer struct{ srv *http.Server }

func (s *metricsServer) Serve(ctx context.Context)    { _ = s.srv.ListenAndServe() }
func (s *metricsServer) Shutdown(ctx context.Context) { _ = s.srv.Shutdown(ctx) }

metricsMux := http.NewServeMux()
metricsMux.Handle("/metrics", promhttp.Handler())

// apiSrv is e.g. an echo.Server -- it already has Serve(ctx)/Shutdown(ctx).
multiserver.Serve(ctx, apiSrv, &metricsServer{srv: &http.Server{Addr: ":9090", Handler: metricsMux}})
```

`multiserver` exposes only `Serve(ctx, srvs ...Server)`, `Check(ctx)` and `Shutdown(ctx)`.

Splitting metrics from the API port means scraping doesn't compete with user traffic and metrics stay accessible if the API saturates.

## Red flags

| Red flag | Fix |
|---|---|
| Metrics on the same port as the public API exposed to the internet | Move to a dedicated listener (private port) via multiserver |
| Custom registry built per request | One registry at startup; all metrics register against it |
| Metrics with high-cardinality labels (per-user-id, per-trace-id) | Cardinality is a Prometheus killer -- keep label values bounded |
