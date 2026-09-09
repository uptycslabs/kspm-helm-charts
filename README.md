[![Lint Charts](https://github.com/uptycslabs/kspm-helm-charts/actions/workflows/lint-charts.yml/badge.svg?branch=main)](https://github.com/uptycslabs/kspm-helm-charts/actions/workflows/lint-charts.yml)

# Uptycs Kubernetes Helm Charts

Helm charts repository for Uptycs K8sosquery & Kubequery.

## Charts

### [K8sosquery](https://github.com/uptycslabs/kspm-helm-charts/tree/main/charts/k8sosquery)
Helm charts for K8sosquery and Kubernetes resources required for it to function well in a cluster.
### [Kubequery](https://github.com/uptycslabs/kspm-helm-charts/tree/main/charts/kubequery)
Helm charts for Kubequery and Kubernetes resources required for it to function well in a cluster.

## Usage
[Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

1. Add the Helm chart repository:
```console
helm repo add kspm-helm-charts https://uptycslabs.github.io/kspm-helm-charts
```

> [!NOTE]
> If you had already added this repo earlier, please perform a Helm update to retrieve the latest versions of the packages.
> You can then do a Helm search to see the charts.

```console
helm repo update
```

```console
helm search repo kspm-helm-charts
```

2. Download `values.yaml` files for K8sosquery & Kubequery from Uptycs UI. Downloaded file will be a tarball(.tar.gz) package.

> [!TIP]
> Tweak the appropriate fields in downloaded value files to enable or disable different features such as Uptycs Protect, Admission Controllers, and Detections on Audit Logs.

> [!NOTE]
> By default K8sosquery is installed in "uptycs" namespace and Kubequery in "kubequery" namespace but if you want to install the Helm charts and Kubernetes resources in a custom namespace please follow steps 5 and 6 instead of 3 and 4.

3. Perform Helm installation of K8sosquery & Kubequery in chart's default namespace:
```console
helm install k8sosquery -f <path_to_downloaded_k8sosquery_values_file> kspm-helm-charts/k8sosquery
```
```console
helm install kubequery --set deployment.spec.hostname=<cluster_name_in_uptycs_ui> -f <path_to_downloaded_kubequery_values_file> kspm-helm-charts/kubequery
```

4. Verify installation of K8sosquery & Kubequery:
```console
kubectl get po -n uptycs
```
```console
kubectl get po -n kubequery
```

5. Perform Helm installation of K8sosquery & Kubequery in a custom namespace:
```console
helm install k8sosquery -f <path_to_downloaded_k8sosquery_values_file> kspm-helm-charts/k8sosquery --namespace <custom-namespace> --create-namespace
```
```console
helm install kubequery --set deployment.spec.hostname=<cluster_name_in_uptycs_ui> -f <path_to_downloaded_kubequery_values_file> kspm-helm-charts/kubequery --namespace <custom-namespace> --create-namespace
```

6. Verify installation of K8sosquery & Kubequery in custom namespace:
```console
kubectl get po -n <custom-k8sosquery-namespace>
```
```console
kubectl get po -n <custom-kubequery-namespace>
```

## Per-node-pool resource tiers (k8sosquery DaemonSet variants)

By default the `k8sosquery` chart renders one DaemonSet for the whole fleet, so every node gets
the same resources. To give different node classes different resources (e.g. more memory on large
data-plane nodes), set `daemonset.variants` - a list where **each entry renders its own
DaemonSet**. When it is non-empty, the single default DaemonSet is **not** rendered; express a
"catch-all" as its own variant.

Each variant deep-merges over the top-level `daemonset` settings and typically overrides `name`
(required, unique), scheduling (`nodeSelector` / `affinity` / `tolerations`), and
`containers.resources`.

Two merge caveats:

- **Resource variants should be self-contained.** The merge is key-by-key, so a variant that sets
  only `containers.resources.limits.memory` silently inherits the base `limits.cpu` - spell out
  the full `limits` and `requests` (both `cpu` and `memory`) in a resource variant, or you can end
  up with a mismatched limit (e.g. a raised memory limit paired with a CPU limit still sized for
  the base tier).
- **Lists replace, they don't merge.** Map fields deep-merge key-by-key, but list-valued fields
  (`tolerations`, `env`, `volumes`) are replaced wholesale by the variant's list - restate any base
  list entries (e.g. the default master/control-plane tolerations) you want to keep.

Two invariants:

- **At most one agent per node - enforced.** Every pod gets a required one-per-node
  `podAntiAffinity` (on `app.kubernetes.io/name`, hostname topology), so two agents can never run
  on the same node. During a single-DaemonSet -> variants migration this makes the cutover a
  per-node hand-off (new pods stay `Pending` until the old drain) rather than a two-agent overlap.
- **The right tier on the right node - your job.** Anti-affinity guarantees "not two", not "the
  correct one". If two variants can match a node, which wins is nondeterministic and the loser
  stays `Pending`. So make variants **mutually exclusive**: use `tolerations` to land a variant
  **onto** tainted nodes, and `nodeSelector`/`affinity` to keep other variants **off** them (a
  catch-all must positively exclude the specialized pools, e.g. `nodeAffinity ... NotIn [...]`).
  Exclusion keys off node **labels**, not taints.

Example:

    daemonset:
      variants:
        - name: high-memory
          nodeSelector: { node-pool: high-memory }
          tolerations:
            - { key: dedicated, value: high-memory, effect: NoSchedule }
          containers:
            resources: { limits: { memory: 1Gi }, requests: { cpu: 200m, memory: 256Mi } }
        - name: default
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                      - { key: node-pool, operator: NotIn, values: [high-memory] }
          containers:
            resources: { limits: { memory: 256Mi }, requests: { cpu: 200m, memory: 100Mi } }

This renders DaemonSets `uptycs-osquery-high-memory` and `uptycs-osquery-default`, each carrying a
`uptycs.io/variant` label. Migrating an existing install from the single DaemonSet to variants
replaces the DaemonSet object (old `uptycs-osquery` removed, `uptycs-osquery-<variant>` created);
thanks to the anti-affinity the agent pods roll over per node with a brief gap, not an overlap.
