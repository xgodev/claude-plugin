**REQUIRED BACKGROUND:**
- `references/start.md` — `boost.Start()` first.
- `references/factory/echo.md` — endpoints typically attach to the Echo server.
- `references/model-restresponse.md` — `restresponse.NewHealth(ctx)` is what actually turns registered checks into an HTTP response.

## Liveness vs readiness — keep them separate

| Endpoint | Answers | Fails when |
|---|---|---|
| `/livez` (or `/health`) | "Is the process alive?" | Process should be killed and restarted |
| `/readyz` | "Should I receive traffic right now?" | A downstream is unhealthy; don't pull this pod from rotation, just stop sending requests |

Cascading failure mode to avoid: a transient downstream blip flips `/health` to 500, Kubernetes kills the pod, the new pod hits the same downstream, gets killed, replicas churn → total outage from a recoverable hiccup. Liveness probes must NOT depend on downstream state.

## Registering a checker

```go
import "github.com/xgodev/boost/extra/health"

type Checker interface {
    Check(ctx context.Context) error
}
```

A checker is any type implementing `Check(ctx context.Context) error` — nil means healthy. Register it once at boot via `health.Add`, which appends to the package-level check list:

```go
func Add(checker *HealthChecker)

func NewHealthChecker(name string, description string, checker Checker, required bool, enabled bool) *HealthChecker
```

```go
type dbChecker struct{ db *sql.DB }

func (c *dbChecker) Check(ctx context.Context) error {
    return c.db.PingContext(ctx)
}

health.Add(health.NewHealthChecker(
    "database",
    "PostgreSQL connection check",
    &dbChecker{db: db},
    true,  // required: failing this returns 503
    true,  // enabled
))

health.Add(health.NewHealthChecker(
    "redis",
    "Redis cache check",
    &redisChecker{client: redisClient},
    false, // not required: failing this returns 207, not 503
    true,
))
```

`required` controls severity, not whether the check runs: a failing non-required checker still shows up in the response, it just doesn't take the whole service down.

## Wiring the endpoint

Registration alone doesn't serve anything — attach `restresponse.NewHealth` to a route:

```go
srv.GET("/readyz", func(c echo.Context) error {
    health, statusCode := restresponse.NewHealth(c.Request().Context())
    return c.JSON(statusCode, health)
})
```

`NewHealth(ctx)` runs every registered checker via `health.CheckAll(ctx)` and derives the HTTP status: 200 if every check (required or not) passes, 503 if any `required` check fails, 207 if only non-required checks failed.

## Implementation tips

- **Bound the timeout** on each `Check` (`context.WithTimeout`) so a hung downstream doesn't hang the readiness response.
- **Don't include the publisher** in liveness — publishing to a downed Pub/Sub topic should not kill the pod.
- **Liveness stays static** — `/livez` should not call `health.CheckAll`; return a fixed 200.

## Red flags

| Red flag | Fix |
|---|---|
| Liveness probe runs downstream checks (DB, Redis, Pub/Sub) | Move downstream checks to readiness; liveness stays static |
| Single `/health` endpoint serving both probes | Split into `/livez` (static) and `/readyz` (`health.CheckAll` via `restresponse.NewHealth`) |
| Checker without a context timeout | Wrap with `context.WithTimeout(ctx, 2*time.Second)` inside `Check` |
| Calling `health.CheckAll` directly and hand-rolling the status code | Use `restresponse.NewHealth(ctx)` — it already derives 200/207/503 |
| Inventing `NewDBChecker`/`NewRedisChecker`/`NewPubSubChecker` helpers | They don't exist — implement `Checker` yourself and wrap with `health.NewHealthChecker(...)` |
