**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Composed by `references/factory/bigquery.md`, `references/factory/firestore.md`, `references/factory/pubsub.md`.

## What it provides

Shared GCP API options (credentials JSON, endpoint URL, user-agent). The package registers nothing on its own -- it only exports `ConfigAdd(path)`, which each concrete GCP factory calls at `<service-root>.apiOptions` (e.g. `boost.factory.gcp.pubsub.apiOptions`). There is no `boost.factory.gcp.api.*` root and no inheritance. You rarely import this package directly -- you configure the per-service keys instead.

## Tunables

- `apiOptions.projectId` -- GCP project
- `apiOptions.credentials.json` / `apiOptions.credentials.file` -- service-account override
- `apiOptions.endpoint` -- emulator URL (e.g., `localhost:8085` for the Pub/Sub emulator) or private endpoint
- `apiOptions.userAgent` -- header used in API calls

Override per-service: a dedicated emulator for the BigQuery factory only:

```
BOOST_FACTORY_GCP_BIGQUERY_APIOPTIONS_ENDPOINT=localhost:9050
```

## Red flags

| Red flag | Fix |
|---|---|
| Expecting a shared `boost.factory.gcp.api.*` root that service factories inherit | No such root exists -- set the keys on each service's own `<service-root>.apiOptions.*` |
| Pointing one env var at all GCP services when only one needs an emulator | Use the per-service `apiOptions.endpoint` override |
| Hardcoded service-account JSON in the repo | Provide via Vault (`references/factory/vault.md`) or workload identity |
