**REQUIRED BACKGROUND:**
- `references/start.md` — `boost.Start()` calls `log.Set(zerolog.NewLogger())` for you; this is the default.
- `references/wrapper/log.md` — the abstraction you log through; switching backends never changes call sites.
- `references/wrapper/config.md` — `boost.factory.zerolog.*` namespacing / env override semantics.

## zerolog is the default — usually you write no logger code

```go
import (
    "github.com/xgodev/boost"
    "github.com/xgodev/boost/wrapper/log"
)

func main() {
    boost.Start()                 // log.Set(zerolog.NewLogger()) happens INSIDE Start (start.go)
    log.Infof("hello world!!")    // already zerolog, config-driven
}
```

`boost.Start()` (see `start.go`) imports `factory/contrib/rs/zerolog/v1` and runs `log.Set(zerolog.NewLogger())` after `config.Load()`. An explicit `log.Set(zerolog.NewLogger())` in your `main` is **redundant** — only re-set if a previous line swapped the backend and you need to swap back. `zerolog.NewLogger()` returns a `log.Logger` and `panic`s if options fail to load.

## Config tree — `boost.factory.zerolog` (cited from `factory/contrib/rs/zerolog/v1/config.go`)

| Key | Default | What |
|---|---|---|
| `.level` | `INFO` | log level (top-level, **not** under `.console`) |
| `.console.enabled` | `true` | console sink on/off |
| `.file.enabled` | `false` | file sink on/off |
| `.file.path` | `/tmp` | log directory |
| `.file.name` | `application.log` | log filename |
| `.file.maxsize` | `100` | rotation size (MB) |
| `.file.compress` | `true` | gzip rotated files |
| `.file.maxage` | `28` | retention (days) |
| `.formatter` | `TEXT` | `TEXT`, `JSON`, or `AWS_CLOUD_WATCH` |

Operators override via env, e.g. `BOOST_FACTORY_ZEROLOG_LEVEL=DEBUG`, `BOOST_FACTORY_ZEROLOG_FORMATTER=JSON`. Note the level key is `boost.factory.zerolog.level` (flat), unlike zap/logrus which nest it under `.console.level`.

## Red flags

| Red flag | Fix |
|---|---|
| `zerolog.New(os.Stderr)` / `zerolog.Logger` constructed in app code | Backend is already set by `boost.Start()`; log via `references/wrapper/log.md` |
| Redundant `log.Set(zerolog.NewLogger())` right after `boost.Start()` | Delete it — `Start()` already did it |
| Setting `boost.factory.zerolog.console.level` to change level | The level key is flat: `boost.factory.zerolog.level` (env `BOOST_FACTORY_ZEROLOG_LEVEL`) |
| Switching to JSON by wrapping the writer | Set `boost.factory.zerolog.formatter=JSON` (or `AWS_CLOUD_WATCH`) |
| Constructing your own logger per request | Pull request-scoped loggers via `log.FromContext(ctx)` |
