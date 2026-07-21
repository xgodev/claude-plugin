**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import vaultfact "github.com/xgodev/boost/factory/contrib/mittwald/vaultgo/v0"

vc, err := vaultfact.NewClient(ctx)
if err != nil { log.Fatalf("vault: %v", err) }
```

Configure under `boost.factory.vault.*` (override `BOOST_FACTORY_VAULT_*`): `.addr`, `.caPath`, `.type` (`TOKEN`/`K8S`/`JWT`, default `TOKEN`), `.token`, and for K8S `.k8s.role` plus `.k8s.jwt.file` / `.k8s.jwt.content`. The client only builds auth for `TOKEN` and `K8S` -- there is no approle and no namespace key.

## Two `ConfigAdd` entry points

| Entry | Purpose |
|---|---|
| `vaultfact.ConfigAdd(path)` | Register a client config root |
| `vaultfact.ManagerConfigAdd(path)` | Register a secret manager root (wraps the client + caches reads) |

Pick the manager when you need cached, periodic refresh; pick the raw client for one-shot reads at startup.

## Pattern: read secrets at startup, pass them to the factory

`wrapper/config` has no key/value setter (`config.Set` takes a `Provider`, not a path+value), so you cannot inject a secret back into the config tree. Pass it explicitly through the factory's `*WithOptions` constructor instead:

```go
vc, _ := vaultfact.NewClient(ctx)
secret, _ := vc.Read(ctx, "secret/data/myapp/db")

o, _ := pgx.NewOptions()
o.Password = secret.Data["password"].(string)

db, _ := pgx.NewDBWithOptions(ctx, o)
```

## Red flags

| Red flag | Fix |
|---|---|
| `vault.NewClient(...)` from upstream SDK directly | `vaultfact.NewClient(ctx)` |
| Vault address / token via `os.Getenv` | `BOOST_FACTORY_VAULT_*` |
| Re-fetching the same secret per request | Use the manager (`ManagerConfigAdd`) so reads are cached |
| Hardcoding secrets in config files | Vault dev profile or `.env.local` outside the repo |
