**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import vaultfact "github.com/xgodev/boost/factory/contrib/mittwald/vaultgo/v0"

vc, err := vaultfact.NewClient(ctx)
if err != nil { log.Fatalf("vault: %v", err) }
```

Configure address, auth method (token, k8s, approle), namespace under `boost.factory.vault.*` (override `BOOST_FACTORY_VAULT_*`).

## Two `ConfigAdd` entry points

| Entry | Purpose |
|---|---|
| `vaultfact.ConfigAdd(path)` | Register a client config root |
| `vaultfact.ManagerConfigAdd(path)` | Register a secret manager root (wraps the client + caches reads) |

Pick the manager when you need cached, periodic refresh; pick the raw client for one-shot reads at startup.

## Pattern: read secrets at startup, inject as boost config

```go
vc, _ := vaultfact.NewClient(ctx)
secret, _ := vc.Read(ctx, "secret/data/myapp/db")

// Inject the password into boost config so downstream factories use it
config.Set("boost.factory.pgx.password", secret.Data["password"])

db, _ := pgx.NewDB(ctx)   // picks up the injected password
```

## Red flags

| Red flag | Fix |
|---|---|
| `vault.NewClient(...)` from upstream SDK directly | `vaultfact.NewClient(ctx)` |
| Vault address / token via `os.Getenv` | `BOOST_FACTORY_VAULT_*` |
| Re-fetching the same secret per request | Use the manager (`ManagerConfigAdd`) so reads are cached |
| Hardcoding secrets in config files | Vault dev profile or `.env.local` outside the repo |
