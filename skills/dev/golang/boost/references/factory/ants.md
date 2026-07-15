**REQUIRED BACKGROUND:** `references/start.md`.

```go
import (
    antsfact "github.com/xgodev/boost/factory/contrib/panjf2000/ants/v2"
    "github.com/panjf2000/ants/v2"
)

pool, _ := ants.NewPool(100)
defer pool.Release()

w := antsfact.NewWrapper(pool /* , middlewares ... */)
w.Submit(func() {
    // bounded-concurrency work
})
```

`NewWrapper` lets you stack middlewares (panic recovery, metrics, tracing) around the pool's `Submit` calls without modifying call sites.

## When to bound concurrency

Use ants when fan-out is unbounded by default (consuming a Pub/Sub topic with many messages, processing rows from a large query, calling N external APIs). Without a pool, peak concurrency = number of goroutines spawned, which can saturate the runtime, exhaust file descriptors, or thunder downstream services.

For event-handler functions, the pool fits BETWEEN the handler returning and the publisher middleware writing — useful when republishing fan-out is large.

## Red flags

| Red flag | Fix |
|---|---|
| `go func() { ... }()` in a hot path with no upper bound | Wrap with `pool.Submit` |
| Pool size = `runtime.NumCPU()` for IO-bound work | IO-bound wants more goroutines than CPUs; size based on downstream concurrency budget |
| Forgetting `defer pool.Release()` | Add it — leaked pool blocks shutdown |
