**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Composed by `references/factory/bigquery.md`, `references/factory/firestore.md`, `references/factory/pubsub.md`. For non-GCP gRPC client/server -> `references/factory/grpc.md`.

## What it provides

GCP-tuned gRPC dial options. The package registers nothing on its own -- it only exports `ConfigAdd(path)`, which each concrete GCP factory calls at `<service-root>.grpcOptions` (e.g. `boost.factory.gcp.pubsub.grpcOptions`). There is no `boost.factory.gcp.grpc.*` root. Sensible defaults for GCP API endpoints (keepalive that survives Google's idle close, connect backoff that respects GCP's recommended values, flow-control windows appropriate for streaming responses).

## Tunables (typical)

- `grpcOptions.keepalive.time` / `keepalive.timeout` / `keepalive.permitWithoutStream`
- `grpcOptions.connectParams.backoff.baseDelay` / `.multiplier` / `.jitter` / `.maxDelay`, `connectParams.minConnectTimeout`
- `grpcOptions.initialWindowSize` / `initialConnWindowSize`
- `grpcOptions.tls.enabled` / `.certFile` / `.keyFile` / `.caFile` / `.insecureSkipVerify`

Retry attempts are NOT a gRPC key -- they live on the API side (`apiOptions.retry.maxAttempts`, see `references/factory/gcp-api.md`).

Override per-service: tighter retries on Firestore only:

```
BOOST_FACTORY_GCP_FIRESTORE_APIOPTIONS_RETRY_MAXATTEMPTS=2
```

## Red flags

| Red flag | Fix |
|---|---|
| Building dial options by hand for a GCP service | Configure `<root>.grpcOptions.*` instead |
| Disabling keepalive thinking it saves resources | Google's intermediaries close idle gRPC streams; keepalive prevents costly reconnect storms |
| One global gRPC config across mixed GCP and non-GCP services | Use this skill ONLY for cloud.google.com factories; generic gRPC uses `references/factory/grpc.md` |
