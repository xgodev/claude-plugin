---
name: boost
description: "Use for any work with github.com/xgodev/boost — the modular Go service framework: boot sequence, wrapper (log/config/cache/publisher), bootstrap (function/middleware/adapters), extra (health/middleware/multiserver), fx modules, typed errors, and every factory/contrib integration (databases, messaging, HTTP/RPC, observability, cloud/infra). Triggers on any import under github.com/xgodev/boost, on boost initialization or wiring questions, on writing or reviewing Go service code that uses boost, and on contributing a new component to the boost repo."
license: MIT
metadata:
  author: jpfaria
  version: "2.0.0"
allowed-tools: Read Edit Write Glob Grep Bash(go:*) Bash(golangci-lint:*) Bash(git:*) Agent
---

Index for `github.com/xgodev/boost`. Read the matching context row below, then the leaf reference it points to, before answering. Paths are relative to this skill's directory (`skills/boost/`). Follow any `REQUIRED BACKGROUND` pointer inside a leaf file too.

When wiring or configuring any factory, read that factory's own "Plugins" section too — most accept more than the default/required set shown in the main example (JSON codecs, compression, retry, profiling, docs UI, circuit breakers, observability, …). If the task specifically names OpenTelemetry, Datadog, or Prometheus, or asks for tracing/metrics, also read `references/plugins.md` — that vendor coverage is per-component, not automatic; activating it for one library doesn't activate it for the rest of the stack.

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
