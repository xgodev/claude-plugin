**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. For event-handler integration → `references/bootstrap/adapter-nats.md`.

```go
import natsfact "github.com/xgodev/boost/factory/contrib/nats-io/nats.go/v1"

nc, err := natsfact.NewConn(ctx)
if err != nil { log.Fatalf("nats: %v", err) }
defer nc.Close()
```

Configure servers, credentials, name, reconnect policy under `boost.factory.nats.*` (override `BOOST_FACTORY_NATS_*`).

## Factory vs adapter

| Use case | Reach for |
|---|---|
| Direct subscription / publish / request-reply, JetStream | `references/factory/nats.md` (raw conn) |
| Event handler over CloudEvents semantics with middleware chain | `references/bootstrap/adapter-nats.md` |

## Red flags

| Red flag | Fix |
|---|---|
| `nats.Connect(url)` directly | `natsfact.NewConn(ctx)` |
| Servers/creds via `os.Getenv` | `BOOST_FACTORY_NATS_*` |
| Forgetting `defer nc.Close()` | Add it |
