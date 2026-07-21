**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import ftpfact "github.com/xgodev/boost/factory/contrib/jlaffaye/ftp/v0"

conn, err := ftpfact.NewServerConn(ctx)
if err != nil { log.Fatalf("ftp: %v", err) }
defer conn.Quit()
```

Configure address (`.addr`), `.username`, `.password`, `.timeout` and `.retry` under `boost.factory.jlaffaye.*` (override `BOOST_FACTORY_JLAFFAYE_*`).

Multi-target pattern: `ftpfact.ConfigAdd("boost.factory.jlaffaye.<partner>")` per partner FTP, then `NewServerConnWithConfigPath(ctx, "boost.factory.jlaffaye.<partner>")`.

## Red flags

| Red flag | Fix |
|---|---|
| `ftp.Dial(addr)` directly | `ftpfact.NewServerConn(ctx)` |
| Credentials via `os.Getenv` | `BOOST_FACTORY_JLAFFAYE_*` |
| Forgetting `defer conn.Quit()` | Add it |
| Sharing a single connection across goroutines | jlaffaye/ftp connections are NOT goroutine-safe -- one per worker |
