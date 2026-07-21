**REQUIRED BACKGROUND:** `references/start.md`. For event-driven function CLI shape (`fn.Run` uses cobra internally) -> `references/bootstrap/function.md`.

```go
import cobrafact "github.com/xgodev/boost/factory/contrib/spf13/cobra/v1"
import co "github.com/spf13/cobra"

root := &co.Command{Use: "myapp"}
sync := &co.Command{Use: "sync", RunE: runSync}
backfill := &co.Command{Use: "backfill", RunE: runBackfill}

err := cobrafact.Run(root, sync, backfill)
```

`Run(root, subcommands...)` (and `RunContext(ctx, root, subcommands...)`) is what wires boost in: it attaches the subcommands, turns every registered boost config entry into a persistent flag, adds the `--conf` flag for config file paths, and then calls `Execute()` / `ExecuteContext(ctx)`.

`NewCommand(root, subcommands...)` only calls `root.AddCommand(subcommands...)` and returns the root -- no boost wiring. Using `NewCommand(...)` + `cmd.Execute()` loses the config flags.

## When to use vs when to skip

Use cobra when the binary genuinely has multiple modes (sync, backfill, migrate, dev tools). For single-purpose binaries (a function or an HTTP API), skip cobra -- `boost.Start()` + a plain `main` is simpler.

## Red flags

| Red flag | Fix |
|---|---|
| Hand-rolling cobra with no boost integration | `cobrafact.Run(root, ...)` |
| `cobrafact.NewCommand(root, ...)` + `cmd.Execute()` | Only adds subcommands -- use `cobrafact.Run` / `RunContext` to get the config flags |
| Defining subcommands inside `init()` of multiple files | Compose them in `main`, not via package-init side effects |
| Reading flags via `os.Args` directly | Use cobra's `cmd.Flags()` |
