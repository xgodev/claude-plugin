**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Layout/trio convention → `references/CONTRIBUTING.md`.

```go
import oracle "github.com/xgodev/boost/factory/contrib/godror/godror/v0"

db, err := oracle.NewDB(ctx)
if err != nil { log.Fatalf("oracle: %v", err) }
defer db.Close()
```

Returns `*sql.DB` backed by godror. Configure DSN, user, password, pool sizes under `boost.factory.godror.*` (override `BOOST_FACTORY_GODROR_*`).

## Observability plugins

`oracle.NewDB(ctx, plugins ...Plugin)` shares its `Plugin` interface with every `database/sql`-backed factory (`factory/core/database/sql`, same slot pgx uses — see `references/factory/pgx.md`):

| Vendor | Import | Usage |
|---|---|---|
| Datadog | `.../factory/core/database/sql/plugins/contrib/datadog/dd-trace-go/v1` | `oracle.NewDB(ctx, datadog.NewDatadog().Register)` |
| OpenTelemetry | `.../factory/core/database/sql/plugins/contrib/xsam/otelsql/v0` | `oracle.NewDB(ctx, otelsql.NewOTel().Register)` |

> **Runtime requirement:** godror needs Oracle Instant Client present at runtime — verify your container/host has the libs before wiring. Build will succeed without them; the connection at startup will fail.

## Red flags

| Red flag | Fix |
|---|---|
| `sql.Open("godror", dsn)` with hand-built DSN | `oracle.NewDB(ctx)` |
| Credentials via `os.Getenv` | `BOOST_FACTORY_GODROR_*` |
| Skipping Oracle Instant Client setup in deployment | Add to base image / install step |
| Forgetting `defer db.Close()` | Add it |
