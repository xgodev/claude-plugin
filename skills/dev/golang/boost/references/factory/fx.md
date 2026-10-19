**REQUIRED BACKGROUND:** `references/start.md`, `references/fx/modules.md` (composition patterns), `references/wrapper/log.md` (the logger fx uses).

In a builder app (every new app) `main.go` is generated and calls `fxfact.NewApp(<app>.Modules()...).Run()` (`references/builder.md`); call the factory by hand only in an app wired by hand.

The factory wraps `go.uber.org/fx`'s `fx.New` with exactly one boost default: it prepends `fx.WithLogger(NewEventLogger)`, an `fxevent.Logger` that writes fx's console lines through `wrapper/log` at `boost.factory.fx.log.level` (DEBUG by default), and every event that carries an error (a constructor, invoke or hook that failed, `Failed to start`, a failed stop) at ERROR whatever that level, so the reason an app exits always reaches the log. Nothing else is wired -- lifecycle, `OnStart` / `OnStop` and their contexts behave exactly as in raw fx. (`fx.Logger`/`NewLogger()` is the old printer; do not add it.)

```go
import (
    "go.uber.org/fx"
    fxfact "github.com/xgodev/boost/factory/contrib/go.uber.org/fx/v1"
)

func main() {
    boost.Start()

    app := fxfact.NewApp(
        myModule.Module(),
        otherModule.Module(),
        fx.Provide(NewService),
        fx.Invoke(registerRoutes),
    )
    app.Run()
}
```

## When to use this vs raw `fx.New`

Use the factory when you want fx events (provider registration, lifecycle transitions) to flow through `wrapper/log` instead of fx's own stdout writer. For libraries that ship modules but don't run an app, raw `fx.Module(...)` is fine.

## Fail loud at boot

A constructor in `fx.Provide` or an `fx.Invoke` that returns an error makes fx fail the app build and `app.Run()` exit non-zero; `NewApp` logs that error at ERROR, but the error is only as good as its text. So **validate loudly**: in the provider, log the specific failure (which key, which value) *before* returning the error, and prefer `errors.NewInternal(err, "config: <key>=<value>")` over a bare error. A silent `exit 1` once the logger is up almost always means a provider rejected its config -- make sure the provider says which one. (dev-rules LAW 4: fail loud, fail specific.)

## Red flags

| Red flag | Fix |
|---|---|
| `fx.New(...)` directly with `fx.WithLogger(fxevent.NopLogger)` | `fxfact.NewApp(...)` so events flow through `wrapper/log` |
| `fx.Logger(...)` added next to `fxfact.NewApp` | Drop it: `NewApp` already installs the event logger |
| A boot provider returns a bare error on bad config -> opaque `exit 1` | Log the specific bad key/value in the provider before returning; wrap with `errors.NewInternal(err, "config: <key>=<value>")`. A swallowed boot error costs hours to diagnose. |
| `app.Run()` before `boost.Start()` | `boost.Start()` is always first |
| Mixing `fxfact.NewApp` with `fx.New` in the same binary | Pick one |
