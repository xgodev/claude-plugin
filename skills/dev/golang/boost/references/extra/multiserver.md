**REQUIRED BACKGROUND:**
- `references/start.md` — `boost.Start()` first.
- `references/factory/echo.md` — the typical primary listener.

## When you need it

A single binary listening on multiple ports — for example:
- Main API on `:8080` (Echo HTTP).
- Prometheus scraper on `:9090` (`/metrics`).
- Internal gRPC on `:9000`.

Without `multiserver`, you end up writing ad-hoc goroutine + WaitGroup orchestration per listener.

## The `Server` interface

Anything passed to `multiserver` must implement:

```go
type Server interface {
    Serve(context.Context)
    Shutdown(context.Context)
}
```

`Serve` is the blocking server loop; `Shutdown` is the graceful drain. Adapt whatever framework you're using (Echo, gRPC, …) to this interface — it does not ship built-in adapters.

## Wiring

```go
import "github.com/xgodev/boost/extra/multiserver"

type echoServer struct {
    echo *echo.Echo
    addr string
}

func (e *echoServer) Serve(ctx context.Context)    { e.echo.Logger.Fatal(e.echo.Start(e.addr)) }
func (e *echoServer) Shutdown(ctx context.Context) { e.echo.Shutdown(ctx) }

type grpcServer struct {
    server *grpc.Server
    lis    net.Listener
}

func (g *grpcServer) Serve(ctx context.Context)    { g.server.Serve(g.lis) }
func (g *grpcServer) Shutdown(ctx context.Context) { g.server.GracefulStop() }

ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer cancel()

multiserver.Serve(ctx, &echoServer{echo: e, addr: ":8080"}, &grpcServer{server: gs, lis: lis})
```

`Serve(ctx, srvs...)` panics if called with zero servers. For one server it blocks directly; for several it launches each in its own goroutine and waits for all to complete.

## Check and Shutdown

```go
func Check(ctx context.Context) error     // nil if every registered server reports Ok; else a ServiceUnavailable error
func Shutdown(ctx context.Context)        // calls Shutdown(ctx) on every registered server; panics if none are configured
```

`Check` is what you'd wire into a readiness checker (see `references/extra/health.md`) to fail readiness if one of the multiplexed servers went down without crashing the process.

## Red flags

| Red flag | Fix |
|---|---|
| Hand-rolled `sync.WaitGroup` + N `go server.Serve` calls | Use `multiserver.Serve(ctx, srvs...)` so failure semantics are uniform |
| A server type that doesn't implement both `Serve(context.Context)` and `Shutdown(context.Context)` | Add an adapter type wrapping the underlying server/framework |
| Calling `multiserver.New()` / `.WithServer()` / `ms.Run(ctx)` | That builder API doesn't exist — the real entry points are the package-level `Serve`, `Check`, `Shutdown` functions |
| Forgetting to wire `Shutdown` to the process signal context | Pass a `signal.NotifyContext` into `Serve` so SIGTERM drains every listener |
