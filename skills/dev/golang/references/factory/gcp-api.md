**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`. Composed by `references/factory/bigquery.md`, `references/factory/firestore.md`, `references/factory/pubsub.md`.

## What it provides

Shared GCP API options (credentials JSON, endpoint URL, user-agent) registered under `boost.factory.gcp.api.*` and composed by every concrete GCP factory at `<root>.apiOptions.*`. You rarely import this skill's package directly — you configure its keys instead.

## Tunables

- `apiOptions.projectID` — GCP project
- `apiOptions.credentialsJSON` / `apiOptions.credentialsFile` — service-account override
- `apiOptions.endpoint` — emulator URL (e.g., `localhost:8085` for the Pub/Sub emulator) or private endpoint
- `apiOptions.userAgent` — header used in API calls

Override per-service: a dedicated emulator for the BigQuery factory only:

```
BOOST_FACTORY_GCP_BIGQUERY_APIOPTIONS_ENDPOINT=localhost:9050
```

## Red flags

| Red flag | Fix |
|---|---|
| Setting GCP credentials at the cloud-google service factory level when multiple services share them | Set under `boost.factory.gcp.api.*` once; service factories inherit |
| Pointing one env var at all GCP services when only one needs an emulator | Use the per-service `apiOptions.endpoint` override |
| Hardcoded service-account JSON in the repo | Provide via Vault (`references/factory/vault.md`) or workload identity |
