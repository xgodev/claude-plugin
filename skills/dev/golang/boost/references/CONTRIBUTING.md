**REQUIRED BACKGROUND:**
- `references/wrapper/config.md` -- config.Add semantics; new code registers its keys.
- `references/wrapper/log.md` -- logger access pattern in driver code.
- `references/model-errors.md` -- error verbs to mirror.

## Layout convention

| Adding | Path |
|---|---|
| Publisher driver | `wrapper/publisher/driver/contrib/<vendor>/<lib>/v<major>/` |
| Cache driver | `wrapper/cache/driver/contrib/<vendor>/<lib>/v<major>/` |
| Logger contrib | `wrapper/log/contrib/<vendor>/<lib>/v<major>/` |
| Function adapter | `bootstrap/function/adapter/contrib/<vendor>/<lib>/v<major>/` |
| Function middleware | `bootstrap/function/middleware/<name>/` |
| Factory contrib | `factory/contrib/<vendor>/<lib>/v<major>/` |
| Echo plugin | `factory/contrib/labstack/echo/v4/plugins/{native,contrib,extra,local}/<name>/` -- `native/` = echo's own middleware (cors, gzip, recover, ...), `contrib/` = third-party vendor (datadog, go.opentelemetry.io, prometheus, goccy, bytedance, swaggo, hiko1129) and versioned like a factory contrib (`contrib/<vendor>/<lib>/v<major>/`), `extra/` = boost-authored generic (error_handler, semaphore), `local/` = wires another boost package (`local/extra/health`, `local/wrapper/log`, `local/model/restresponse`) |
| Fx module | `fx/modules/<area>/<component>/` |

**Package name = the short library name** (`pubsub`, `nats`, `confluent`, `goka`, `sns`, `redis`), **not** the version directory leaf. Alias the upstream SDK at the import site if a name clash would occur:

```go
import asns "github.com/aws/aws-sdk-go-v2/service/sns"
```

## Multi-service SDKs (AWS SDK v2, Azure SDK, GCP SDK)

For `wrapper/`, `bootstrap/`, and `extra/` -- split per service:

```
wrapper/publisher/driver/contrib/aws/sns/v1/
wrapper/publisher/driver/contrib/aws/sqs/v1/
wrapper/cache/driver/contrib/aws/dynamodb/v1/
```

Do **not** nest under the SDK module dir (`aws/aws-sdk-go-v2/v1/`). The umbrella SDK layout (`factory/contrib/aws/aws-sdk-go-v2/v1/client/<service>/`) is **exclusive to `factory/contrib/`** because factories ship clients that legitimately share an SDK version pin. Drivers don't.

## Factory contrib shape -- server and client

The shape every new `factory/contrib/` package takes. Build from this section
instead of re-reading boost sources; open the gRPC factory
(`factory/contrib/google.golang.org/grpc/v1/{server,client}`) and echo
(`factory/contrib/labstack/echo/v4`) only to confirm a detail.

```
factory/contrib/<vendor>/<lib>/v<major>/
  server/                      # package server -- when the lib serves
    config.go                  # root, PluginsRoot, init() + ConfigAdd(path)
    options.go                 # Options, NewOptions, NewOptionsWithPath
    server.go                  # Plugin, Server, constructor trio, Serve, Shutdown
    plugins/{native,contrib,local}/...   # same split as the echo plugin row above
    README.md
  client/                      # package client -- when the lib calls out
    config.go  options.go  client.go  plugins/...  README.md
fx/modules/factory/contrib/<vendor>/<lib>/v<major>/{server,client}/module.go
```

A lib with one side only keeps the files directly in `v<major>/`, package =
short lib name (`echo`).

```go
// config.go
const (
	root        = "boost.factory.<lib>.server"
	port        = ".port"
	PluginsRoot = root + ".plugins" // each plugin package roots its keys here
)

func init() { ConfigAdd(root) }

// ConfigAdd registers the keys under path (a second instance on another port).
func ConfigAdd(path string) {
	config.Add(path+port, 8080, "server port")
}

// options.go
type Options struct{ Port int }

func NewOptions() (*Options, error) { return config.NewOptionsWithPath[Options](root) }

func NewOptionsWithPath(path string) (*Options, error) {
	return config.NewOptionsWithPath[Options](root, path) // root defaults, path overrides
}

// server.go
// Plugin customizes the server right after it is built.
type Plugin func(context.Context, *Server) error

type Server struct {
	instance *upstream.Server
	options  *Options
}

func NewServer(ctx context.Context, plugins ...Plugin) (*Server, error)
func NewServerWithConfigPath(ctx context.Context, path string, plugins ...Plugin) (*Server, error)
func NewServerWithOptions(ctx context.Context, o *Options, plugins ...Plugin) (*Server, error)

func (s *Server) Instance() *upstream.Server // apps register their handlers on it
func (s *Server) Serve(ctx context.Context)   // blocks until stopped
func (s *Server) Shutdown(ctx context.Context)
```

- `Serve` + `Shutdown` with these exact signatures make the server an
  `extra/multiserver.Server`; that is what lets it run beside echo and gRPC.
- `Plugin`: if `github.com/xgodev/boost/factory` exports `Plugin[T]` in the
  checkout, declare `type Plugin = factory.Plugin[*Server]` and run them with
  `factory.ApplyPlugins`; otherwise the func type above (same signature, so the
  later alias is not a break). Client side: `func(context.Context, *Client) error`.
- Constructors return the error. No `panic`, no `log.Fatal` -- the gRPC
  server's `Fatalf` on listen is legacy, do not copy it. `Serve` logs the
  serve error through `log.FromContext(ctx)` and stays quiet on the
  graceful-stop sentinel (`http.ErrServerClosed`).
- A plugin package (`plugins/local/wrapper/log/`): `config.go` with
  `root = server.PluginsRoot + ".log"`, `init() { ConfigAdd(root) }` and an
  `.enabled` key; `options.go` as above; a package-level
  `Register(ctx context.Context, srv *server.Server) error` that loads its
  options, returns nil when disabled and returns the options error otherwise.
  Observability plugins go under `plugins/contrib/<vendor>/<lib>/v<major>/`
  (OTel, Datadog, Prometheus -- `references/plugins.md`).

```go
// fx/modules/factory/contrib/<vendor>/<lib>/v<major>/server/module.go
import (
	s "github.com/xgodev/boost/extra/multiserver"
	"github.com/xgodev/boost/fx/modules/extra/multiserver"
)

type params struct {
	fx.In
	Plugins []server.Plugin `optional:"true"`
}

// inside the once-guarded Module() -- shape in references/fx/modules.md
fx.Provide(
	func(ctx context.Context, p params) (*server.Server, error) {
		return server.NewServer(ctx, p.Plugins...)
	},
	fx.Annotated{
		Group:  multiserver.ServersGroupKey,
		Target: func(srv *server.Server) s.Server { return srv },
	},
)
```

The client module provides `*client.Client` the same way, without the group;
a client holding a connection closes it with
`lc.Append(fx.StopHook(cli.Close))` (gRPC client module).

## Constructor trio

```go
func New(ctx context.Context, c *upstream.Client) (publisher.Driver, error)
func NewWithOptions(ctx context.Context, c *upstream.Client, opts *Options) publisher.Driver
func NewWithConfigPath(ctx context.Context, c *upstream.Client, path string) (publisher.Driver, error)
```

This is the trio to aim for in NEW code, so call sites are interchangeable -- but it is not universal today. Among publisher drivers only Pub/Sub (`wrapper/publisher/driver/contrib/cloud.google.com/pubsub/v1`) and Confluent Kafka (`.../confluentinc/confluent-kafka-go/v2`) ship all three; NATS exposes only `New(conn *nats.Conn) publisher.Driver` and Goka only `New(emitter *g.Emitter) publisher.Driver`, both with no `Options` and no `config.go`. Mirror the closest existing contrib: a driver with real tunables gets the full trio + config registration; a thin driver with nothing to configure can stay at a single `New`.

## Config registration

```go
// config.go
package <pkg>

import "github.com/xgodev/boost/wrapper/config"

const root = "boost.wrapper.publisher.driver.<name>"

func init() {
    config.Add(root+".log.level", "INFO", "log level")
    config.Add(root+".publishTimeout", "10s", "per-event publish timeout")
}

// ConfigAdd -- exported so multi-instance consumers can register at a non-default path.
func ConfigAdd(path string) {
    config.Add(path+".log.level", "INFO", "log level")
    // mirror the rest with `path` instead of `root`
}
```

Multi-instance pattern: one binary publishes to multiple SNS topics / Pub/Sub projects / Kafka clusters by calling `<driver>.ConfigAdd("boost.wrapper.publisher.driver.<name>.<instance>")` per instance.

## Errors and logging

```go
import (
    "github.com/xgodev/boost/model/errors"
    "github.com/xgodev/boost/wrapper/log"
)

logger := log.FromContext(ctx).WithTypeOf(*p)
return nil, errors.Wrap(err, errors.Internalf("publish failed"))
```

Match the verbs in the closest existing driver. boost is consistent enough that diverging stands out in review.

## Honest extrapolation -- `// TODO(maintainer-review):`

When the new driver has no direct precedent, mark every guess inline:

```go
// TODO(maintainer-review): SNS requires a full ARN. Falling back to options.TopicArn
// when ev.Subject() is not an ARN. Verify this is the wanted behavior, or require
// Subject to always be an ARN.
return p.options.TopicArn
```

Then call out the marked decisions in the PR description so reviewers know where their judgment is needed.

## What NOT to add

- ❌ Code under `bootstrap/` for a wrapper-layer concern (or vice versa). Layering is enforced by directory.
- ❌ A new top-level interface alongside an existing one (`Driver2` is a better `Driver`). Extend the existing one or open an RFC issue first.
- ❌ A direct dependency on a third-party DI / config / log library. Use `wrapper/config`, `wrapper/log`, and `fx` modules.
- ❌ Tests that `os.Setenv` to inject ordinary config -- build `Options` directly (`New<X>WithOptions`). The one env test worth having proves a key is env-reachable (`BOOST_FACTORY_<X>_<KEY>` lands on `<root>.<key>`): use `t.Setenv` and, on cleanup, set the env back to the key's default and `config.Load()` again. boost's koanf instance is global and a posflag default does not override a key an earlier `Load` already set, so the value leaks into later tests and `-shuffle=on` fails at random.
- ❌ A driver that exposes its concrete type as the public return value of `New(...)`. Return the interface.
- ❌ A `Close()` method on the `Driver` interface itself unless ALL existing implementations need it. Optional close = separate optional interface + feature-detect.

## When to escalate to a human

- New top-level layer (peer to `bootstrap/`, `factory/`, `wrapper/`) -- architectural change, not a contrib.
- Boost-internal bug that blocks the canonical path (like the ctx-loss in adapter helpers, see `references/bootstrap/adapter-pubsub.md`) -- open an issue and propose a PR; don't unilaterally redesign the public API.
- Consumer asks for direct dependency on a non-boost framework (gin, fiber, zap-direct) -- suggest the boost-equivalent first; only deviate with explicit user sign-off.

## Self-test before opening the PR

```bash
go build ./...
go vet ./...
go test ./...
make v 2>/dev/null || go mod vendor   # if you added a dep
```

- [ ] Files at `<area>/<kind>/contrib/<vendor>/<lib>/v<major>/` (or per-service for multi-service SDKs).
- [ ] Package name is the short library name, not the version leaf.
- [ ] Constructor trio present (or a single `New` matching the closest existing contrib, if the driver has no tunables).
- [ ] `init()` calls `config.Add` for every tunable; `ConfigAdd(path)` exported for multi-instance.
- [ ] Errors via `model/errors`; logger via `wrapper/log.FromContext`.
- [ ] Every extrapolation marked with `// TODO(maintainer-review):` and called out in the PR.
- [ ] Public API change: NONE on existing interfaces.
- [ ] Mirror style matches the closest existing contrib.
- [ ] Factory server: `Serve`/`Shutdown`, fx module in the multiserver group; client: fx module closes the connection on stop.
