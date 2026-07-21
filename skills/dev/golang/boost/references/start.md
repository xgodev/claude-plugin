## Iron Law -- `boost.Start()` is the first line of `main`

```go
package main

import "github.com/xgodev/boost"

func main() {
    boost.Start() // ALWAYS first.
    // ... everything else ...
}
```

`Start` does three things, in order:

1. Installs the koanf provider and loads the configuration registry (env vars + config files). After `Start`, calls to `config.String/Int/Bool/Duration` return real values; before, the package-level provider is still `nil`, so every getter **panics** with a nil-pointer dereference.
2. Installs **zerolog** as the structured logger backend -- unconditionally (`log.Set(zerolog.NewLogger())`), not picked by config. After `Start`, `log.FromContext(ctx)` returns that logger; before, it returns a no-op. To run on zap or logrus, call `log.Set(...)` yourself right after `Start` (see `references/wrapper/log-backends.md`).
3. Optionally prints the boot banner (`boost.banner.enabled`) and the table of every registered `config.Add` key (`boost.print.config.enabled`). Both flags default to **false** -- they are opt-in, not part of a normal boot.

## Red flags

| Symptom | Cause | Fix |
|---|---|---|
| Factory constructor (`echo.NewServer`, `fpubsub.NewClient`, etc.) before `boost.Start()` | Constructor reads config that isn't loaded yet | Reorder: `boost.Start()` first |
| `log.FromContext(ctx)` returns silent / no-op logger | `Start` never ran | Add `boost.Start()` as the first statement of `main` |
| `config.String("foo")` panics (nil-pointer dereference) | Same -- no provider installed yet, the getter calls into a `nil` `Provider` | Same -- `boost.Start()` first |

## Cross-references

- For configuration mechanics -> see `references/wrapper/config.md`.
- For logging mechanics -> see `references/wrapper/log.md`.
- For everything else (HTTP, functions, contributing) -> see the relevant subsystem skill.
