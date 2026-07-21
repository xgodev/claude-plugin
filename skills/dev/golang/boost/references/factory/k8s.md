**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import k8sfact "github.com/xgodev/boost/factory/contrib/k8s.io/client-go/v0"

cs := k8sfact.NewClientset(ctx)
// cs is *kubernetes.Clientset
```

Three keys only under `boost.factory.k8s.*` (override `BOOST_FACTORY_K8S_*`): `.type` (`KUBECONFIG`/`INCLUSTER`, default `KUBECONFIG`), `.kubeConfigPath` (default `~/.kube/config`), `.kubeConfigContext`. No QPS/burst tunables.

## In-cluster vs out-of-cluster

In-cluster (running inside a k8s pod): set `boost.factory.k8s.type=INCLUSTER`.

Out-of-cluster (dev / one-off jobs): keep the default `type=KUBECONFIG` and point `boost.factory.k8s.kubeConfigPath` at your kubeconfig (`~/.kube/config` by default), optionally selecting `.kubeConfigContext`.

## Red flags

| Red flag | Fix |
|---|---|
| `kubernetes.NewForConfig(restCfg)` directly with hand-built rest config | `k8sfact.NewClientset(ctx)` |
| Hardcoded kubeconfig path | `BOOST_FACTORY_K8S_KUBECONFIGPATH` |
| Watch loops without `context.Context` cancellation | Pass the lifecycle context -- leaked watches consume API server quota |
