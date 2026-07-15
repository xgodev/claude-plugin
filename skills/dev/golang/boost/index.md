Index for `github.com/xgodev/boost`. Read the matching context row below, then follow its reference chain to the TERMINAL file before answering -- the factory rows route through group indexes (factory.md -> database.md -> pgx.md), so keep following until the file that shows code. Paths are relative to this skill's directory (`skills/dev/golang/boost/`). Follow any `REQUIRED BACKGROUND` pointer inside a leaf file too.

When wiring or configuring any factory, read that factory's own "Plugins" section too -- most accept more than the default/required set shown in the main example (JSON codecs, compression, retry, profiling, docs UI, circuit breakers, observability, ...). If the task specifically names OpenTelemetry, Datadog, or Prometheus, or asks for tracing/metrics, also read `references/plugins.md` -- that vendor coverage is per-component, not automatic; activating it for one library doesn't activate it for the rest of the stack.

| Context | Reference |
|---|---|
| Boot sequence (`boost.Start()`) | `references/start.md` |
| Typed error catalog (`model/errors`) | `references/model-errors.md` |
| REST response envelope (`model/restresponse`) | `references/model-restresponse.md` |
| Contributing a new component | `references/CONTRIBUTING.md` |
| Wrapper (log/config/cache/publisher) | `references/wrapper.md` |
| Bootstrap (function/middleware/adapters) | `references/bootstrap.md` |
| Extra (health/middleware/multiserver) | `references/extra.md` |
| fx modules | `references/fx.md` |
| Factory (`factory/contrib/*`, every integration) | `references/factory.md` |
| Observability vendor coverage matrix (OTel/Datadog/Prometheus, which component has which) | `references/plugins.md` |
