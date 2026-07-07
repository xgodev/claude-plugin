**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

## Canonical examples (ship with boost)

- `factory/contrib/gocql/gocql/v1/examples/ping/main.go`
- `factory/contrib/gocql/gocql/v1/examples/health/main.go`

The `health` example is the reference for wiring this factory into `references/extra/health.md` checkers.

## Construction

```go
import gocqlfact "github.com/xgodev/boost/factory/contrib/gocql/gocql/v1"

session, err := gocqlfact.NewSession(ctx)
if err != nil { log.Fatalf("cassandra: %v", err) }
defer session.Close()
```

Configure hosts, keyspace, consistency, timeouts under `boost.factory.gocql.*` (override `BOOST_FACTORY_GOCQL_*`).

## Red flags

| Red flag | Fix |
|---|---|
| `gocql.NewCluster(...).CreateSession()` direct | `gocqlfact.NewSession(ctx)` |
| Hosts/keyspace via `os.Getenv` | `BOOST_FACTORY_GOCQL_*` |
| Forgetting `defer session.Close()` | Add it |
| Hand-rolled health check instead of mirroring `examples/health` | Mirror the example's shape so checker conventions stay uniform |
