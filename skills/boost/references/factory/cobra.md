**REQUIRED BACKGROUND:** `references/start.md`. For event-driven function CLI shape (`fn.Run` uses cobra internally) → `references/bootstrap/function.md`.

```go
import cobrafact "github.com/xgodev/boost/factory/contrib/spf13/cobra/v1"
import co "github.com/spf13/cobra"

root := &co.Command{Use: "myapp"}
sync := &co.Command{Use: "sync", RunE: runSync}
backfill := &co.Command{Use: "backfill", RunE: runBackfill}

cmd := cobrafact.NewCommand(root, sync, backfill)
cmd.Execute()
```

`NewCommand(root, subcommands...)` wires boost-aware defaults (config flag, version flag, structured logging) onto the root before attaching subcommands.

## When to use vs when to skip

Use cobra when the binary genuinely has multiple modes (sync, backfill, migrate, dev tools). For single-purpose binaries (a function or an HTTP API), skip cobra — `boost.Start()` + a plain `main` is simpler.

## Red flags

| Red flag | Fix |
|---|---|
| Hand-rolling cobra with no boost integration | `cobrafact.NewCommand(root, ...)` |
| Defining subcommands inside `init()` of multiple files | Compose them in `main`, not via package-init side effects |
| Reading flags via `os.Args` directly | Use cobra's `cmd.Flags()` |
