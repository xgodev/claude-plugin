## Iron Law — `boost.Start()` is the first line of `main`

```go
package main

import "github.com/xgodev/boost"

func main() {
    boost.Start() // ALWAYS first.
    // ... everything else ...
}
```

`Start` does three things, in order:

1. Loads the configuration registry (env vars + config files via koanf). After `Start`, calls to `config.String/Int/Bool/Duration` return real values; before, they return zero-values.
2. Installs the structured logger backend (zap / zerolog / logrus, picked by config). After `Start`, `log.FromContext(ctx)` returns the configured logger; before, it returns a no-op.
3. Prints the boot banner + dumps every registered `config.Add` key.

## Red flags

| Symptom | Cause | Fix |
|---|---|---|
| Factory constructor (`echo.NewServer`, `fpubsub.NewClient`, etc.) before `boost.Start()` | Constructor reads config that isn't loaded yet | Reorder: `boost.Start()` first |
| `log.FromContext(ctx)` returns silent / no-op logger | `Start` never ran | Add `boost.Start()` as the first statement of `main` |
| `config.String("foo")` returns `""` even though env var is set | Same — registry empty | Same — `boost.Start()` first |

## Cross-references

- For configuration mechanics → see `references/wrapper/config.md`.
- For logging mechanics → see `references/wrapper/log.md`.
- For everything else (HTTP, functions, contributing) → see the relevant subsystem skill.
