**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Layout/trio convention -> `references/CONTRIBUTING.md`.

**In a builder app (every new app) this page is NOT the wiring:** the `*sql.DB` is generated from `@Inject(index=0, name=gold, drivers=[godror], plugins=[health, otel])` on the constructor's param, keys under `boost.factory.godror.clients.gold.*` (`references/builder.md`, "`*sql.DB`"). No `oracle.NewDB` and no fx module by hand. The code below is for an app without inject.

```go
import oracle "github.com/xgodev/boost/factory/contrib/godror/godror/v0"

db, err := oracle.NewDB(ctx)
if err != nil { log.Fatalf("oracle: %v", err) }
defer db.Close()
```

Returns `*sql.DB` backed by godror. Configure DSN, user, password, pool sizes under `boost.factory.godror.*` (override `BOOST_FACTORY_GODROR_*`).

## Observability plugins

`oracle.NewDB(ctx, plugins ...Plugin)` shares its `Plugin` interface with every `database/sql`-backed factory (`factory/core/database/sql`, same slot pgx uses -- see `references/factory/pgx.md`):

| Vendor | Import | Usage |
|---|---|---|
| Datadog | `.../factory/core/database/sql/plugins/contrib/datadog/dd-trace-go/v1` | `oracle.NewDB(ctx, datadog.NewDatadog())` |
| OpenTelemetry | `.../factory/core/database/sql/plugins/contrib/xsam/otelsql/v0` | `oracle.NewDB(ctx, otelsql.NewOTel())` |

> **Runtime requirement:** godror needs Oracle Instant Client present at runtime -- verify your container/host has the libs before wiring. Build will succeed without them; the connection at startup will fail.

## Red flags

| Red flag | Fix |
|---|---|
| `sql.Open("godror", dsn)` with hand-built DSN | `oracle.NewDB(ctx)` |
| Credentials via `os.Getenv` | `BOOST_FACTORY_GODROR_*` |
| Skipping Oracle Instant Client setup in deployment | Add to base image / install step |
| Forgetting `defer db.Close()` | Add it |
