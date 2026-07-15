**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import k8sfact "github.com/xgodev/boost/factory/contrib/k8s.io/client-go/v0"

cs := k8sfact.NewClientset(ctx)
// cs is *kubernetes.Clientset
```

Configure kubeconfig path, in-cluster vs out-of-cluster auth, QPS/burst under `boost.factory.k8s.*` (override `BOOST_FACTORY_K8S_*`).

## In-cluster vs out-of-cluster

In-cluster (running inside a k8s pod, picks up `/var/run/secrets/...`): leave `boost.factory.k8s.kubeconfig` empty.

Out-of-cluster (dev / one-off jobs): set `boost.factory.k8s.kubeconfig=~/.kube/config`.

## Red flags

| Red flag | Fix |
|---|---|
| `kubernetes.NewForConfig(restCfg)` directly with hand-built rest config | `k8sfact.NewClientset(ctx)` |
| Hardcoded kubeconfig path | `BOOST_FACTORY_K8S_KUBECONFIG` |
| Watch loops without `context.Context` cancellation | Pass the lifecycle context — leaked watches consume API server quota |
