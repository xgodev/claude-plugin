**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Composed by `references/factory/bigquery.md`, `references/factory/firestore.md`, `references/factory/pubsub.md`. For non-GCP gRPC client/server → `references/factory/grpc.md`.

## What it provides

GCP-tuned gRPC dial options registered under `boost.factory.gcp.grpc.*` and composed by every concrete GCP factory at `<root>.grpcOptions.*`. Sensible defaults for GCP API endpoints (keepalive that survives Google's idle close, retry policy that respects GCP's recommended backoff, message-size caps appropriate for streaming responses).

## Tunables (typical)

- `grpcOptions.keepalive.time` / `keepalive.timeout` / `keepalive.permitWithoutStream`
- `grpcOptions.retries.maxAttempts`, retry policy
- `grpcOptions.message.maxRecvSize` / `maxSendSize`

Override per-service: tighter retries on Firestore only:

```
BOOST_FACTORY_GCP_FIRESTORE_GRPCOPTIONS_RETRIES_MAXATTEMPTS=2
```

## Red flags

| Red flag | Fix |
|---|---|
| Building dial options by hand for a GCP service | Configure `<root>.grpcOptions.*` instead |
| Disabling keepalive thinking it saves resources | Google's intermediaries close idle gRPC streams; keepalive prevents costly reconnect storms |
| One global gRPC config across mixed GCP and non-GCP services | Use this skill ONLY for cloud.google.com factories; generic gRPC uses `references/factory/grpc.md` |
