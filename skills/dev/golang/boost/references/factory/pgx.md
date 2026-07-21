**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Layout/trio convention -> `references/CONTRIBUTING.md`.

```go
import pgx "github.com/xgodev/boost/factory/contrib/jackc/pgx/v5"

db, err := pgx.NewDB(ctx)
if err != nil { log.Fatalf("pgx: %v", err) }
defer db.Close()
```

Returns `*sql.DB` (database/sql interface) backed by jackc/pgx v5. Three keys only under `boost.factory.pgx.*` (override `BOOST_FACTORY_PGX_*`): `.connectString` (full DSN -- host, port, database, sslmode all live inside it), `.username`, `.password` (the latter two fill in only when the DSN omits them). Pool sizing is shared, not per-factory: `boost.factory.sql.*` (`.connMaxLifetime`, `.connMaxIdletime`, `.maxIdleConns`, `.maxOpenConns`).

Multi-DB pattern:

```go
pgx.ConfigAdd("boost.factory.pgx.orders")
pgx.ConfigAdd("boost.factory.pgx.analytics")

ordersDB, _    := pgx.NewDBWithConfigPath(ctx, "boost.factory.pgx.orders")
analyticsDB, _ := pgx.NewDBWithConfigPath(ctx, "boost.factory.pgx.analytics")
```

## Observability plugins

`pgx.NewDB(ctx, plugins ...Plugin)` (the `Plugin` interface lives in `factory/core/database/sql`, shared by every `database/sql`-backed factory including godror) accepts:

| Vendor | Import | Usage |
|---|---|---|
| Datadog | `.../factory/core/database/sql/plugins/contrib/datadog/dd-trace-go/v1` | `pgx.NewDB(ctx, datadog.NewDatadog())` |
| OpenTelemetry | `.../factory/core/database/sql/plugins/contrib/xsam/otelsql/v0` | `pgx.NewDB(ctx, otelsql.NewOTel())` |

No Prometheus plugin exists at this shared layer.

## Red flags

| Red flag | Fix |
|---|---|
| `sql.Open("pgx", dsn)` with hand-built DSN | `pgx.NewDB(ctx)` |
| Connection URL via `os.Getenv` | `BOOST_FACTORY_PGX_*` |
| Pool sizes hardcoded | Tune via `boost.factory.sql.maxOpenConns` / `.maxIdleConns` (shared root, not under `boost.factory.pgx`) |
| Forgetting `defer db.Close()` | Add it |
