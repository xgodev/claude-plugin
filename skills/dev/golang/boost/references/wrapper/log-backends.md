**REQUIRED BACKGROUND:**
- `references/wrapper/log.md` -- the wrapper API your code calls (`log.FromContext`).
- `references/wrapper/config.md` -- the per-backend tuning keys (and the `__` env rule).

## Backend selection at boot

```go
import (
    "github.com/xgodev/boost"
    "github.com/xgodev/boost/factory/contrib/go.uber.org/zap/v1"   // or rs/zerolog/v1, or sirupsen/logrus/v1
    "github.com/xgodev/boost/wrapper/log"
)

func main() {
    boost.Start()
    log.Set(zap.NewLogger())   // installs zap as the global backend
    // ... rest of main ...
}
```

After `log.Set`, every `log.FromContext(ctx)` call elsewhere in the service returns a logger backed by zap. Swap to zerolog:

```go
import zerolog "github.com/xgodev/boost/factory/contrib/rs/zerolog/v1"

log.Set(zerolog.NewLogger())
```

Handler code does not change -- it still calls `log.FromContext(ctx).WithField(...)` etc.

## Available backends

| Backend | Path | Best for |
|---|---|---|
| zap | `factory/contrib/go.uber.org/zap/v1` | High throughput, structured |
| zerolog | `factory/contrib/rs/zerolog/v1` | What `boost.Start` installs by default; smallest allocations |
| logrus | `factory/contrib/sirupsen/logrus/v1` | Legacy compat with logrus-using libraries |

## Per-backend config

Each backend has its own config root. Examples (zap):

| Key | What |
|---|---|
| `boost.factory.zap.console.level` | `DEBUG` / `INFO` / `WARN` / `ERROR` (default `INFO`) |
| `boost.factory.zap.console.formatter` | `TEXT` / `JSON` (default `TEXT`) |

Override at deploy via `BOOST_FACTORY_ZAP_CONSOLE_LEVEL`, etc. The other backends do **not** mirror those key paths:

- zerolog -- level is `boost.factory.zerolog.level` (no `console.` segment); formatter is `boost.factory.zerolog.formatter`, `TEXT` / `JSON` / `AWS_CLOUD_WATCH` (default `TEXT`).
- logrus -- level is `boost.factory.logrus.console.level`; formatter is `boost.factory.logrus.formatterType`, `TEXT` / `JSON` / `CLOUDWATCH` (default `TEXT`). Being camelCase, its env var needs the double underscore: `BOOST_FACTORY_LOGRUS_FORMATTER__TYPE`.

Pick **JSON** in production (log aggregators index it) and **TEXT** locally (humans read it).

## Red flags

| Red flag | Fix |
|---|---|
| `log.Set(...)` called more than once in the same process | Call once, in `main`, right after `boost.Start()` |
| Calling `log.Set` inside an `init()` -- before `boost.Start` configured anything | Move to `main` after `boost.Start()` |
| Importing two backend factories simultaneously and switching at runtime | Pick one per binary; switching is a config / deploy decision, not a runtime one |
| Production binary running with the default `formatter=TEXT` | Set the backend's own formatter var to `JSON`: `BOOST_FACTORY_ZAP_CONSOLE_FORMATTER`, `BOOST_FACTORY_ZEROLOG_FORMATTER`, or `BOOST_FACTORY_LOGRUS_FORMATTER__TYPE` |
| Mixing the wrapper (`log.FromContext`) and direct backend calls (`zap.L().Info(...)`) | Use the wrapper exclusively -- direct calls bypass per-context enrichment |
