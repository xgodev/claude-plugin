**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

## Canonical examples (ship with boost)

- `factory/contrib/google.golang.org/grpc/v1/client/examples/examplesvc/` -- minimal client wiring
- `factory/contrib/google.golang.org/grpc/v1/server/examples/examplesvc/` -- minimal server wiring
- `factory/contrib/google.golang.org/grpc/v1/server/examples/examplesvcautotls/` -- server with auto-TLS

Read `examplesvcautotls` before enabling TLS on a new service -- it shows the certificate-manager wiring boost expects.

## Two halves

| Path | When |
|---|---|
| `factory/contrib/google.golang.org/grpc/v1/client/` | Outbound gRPC calls -- dial options, interceptors |
| `factory/contrib/google.golang.org/grpc/v1/server/` | Inbound gRPC service -- listener, interceptors, TLS |

Configure under `boost.factory.grpc.client.*` and `boost.factory.grpc.server.*` (override with the matching `BOOST_FACTORY_GRPC_*` envs).

## GCP-tuned variant

For talking to GCP gRPC APIs (Pub/Sub, BigQuery, Firestore), the cloud-google factories compose `factory/contrib/cloud.google.com/grpc/v1` internally. You normally don't import it directly -- you configure its keys at the per-service factory's `apiOptions` / `grpcOptions` namespace.

## Error → gRPC code (and custom errors)

The server converts errors to gRPC status via `server.Error(err)`, which resolves
the code through `model/errors.Classify` (`NotFound`→`codes.NotFound`,
`NotValid`/`BadRequest`→`InvalidArgument`, `Conflict`/`AlreadyExists`→
`AlreadyExists`, `Unauthorized`→`Unauthenticated`, `Forbidden`→`PermissionDenied`,
`ServiceUnavailable`→`Unavailable`, `NotImplemented`→`Unimplemented`,
`TooManyRequests`→`ResourceExhausted`, `Timeout`→`DeadlineExceeded`, else
`Internal`). To map an app-specific error to a code (or ignore it → returns
`nil`/OK), register it at boot -- see `references/model-errors.md`
(`Register`/`RegisterMatch`/`Ignore`). Don't edit `server.Error` by hand.

## Observability plugins

Both client and server constructors accept `plugins ...Plugin` -- the vendor coverage differs between them:

| Vendor | Client | Server |
|---|---|---|
| Datadog | `.../client/plugins/contrib/datadog/dd-trace-go/v1` → `client.NewClientConn(ctx, datadog.NewDatadog(opts...).Register)` | `.../server/plugins/contrib/datadog/dd-trace-go/v1` → `server.NewServer(ctx, datadog.NewDatadog(opts...).Register)` |
| Prometheus | `.../client/plugins/contrib/prometheus/client_golang/v1` → `..., prometheus.NewPrometheus().Register)` | `.../server/plugins/contrib/prometheus/client_golang/v1` → `..., prometheus.NewPrometheus().Register)` |
| OpenTelemetry | `.../client/plugins/contrib/go.opentelemetry.io/contrib/v0` → `..., contrib.NewOpenTelemetry().Register)` | **not available** -- no otel plugin ships for the gRPC server side |

## Other plugins

| Plugin | Client | Server | What it does |
|---|---|---|---|
| Compressor | `.../client/plugins/native/compressor` → `client.NewClientConnWithOptions(ctx, opts, compressor.NewCompressor().Register)` | `.../server/plugins/native/compressor` → `server.NewServerWithOptions(ctx, opts, compressor.NewCompressor().Register)` | Enables gzip compression for gRPC payloads |

## Red flags

| Red flag | Fix |
|---|---|
| `grpc.Dial(...)` with hand-built dial options | Use the client factory so config + interceptors are wired |
| `grpc.NewServer()` without going through the server factory | Use the server factory so default interceptors (recovery, logging, tracing) are installed |
| TLS config hand-rolled instead of mirroring `examplesvcautotls` | Mirror the example shape -- cert lifecycle is easy to get wrong |
| Forgetting `defer conn.Close()` (client) or `srv.GracefulStop()` (server) | Add them |
