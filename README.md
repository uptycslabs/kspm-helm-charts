# Uptycs Kubernetes Helm Charts

Helm charts repository for Uptycs K8sosquery & Kubequery.

## Charts

### [K8sosquery](https://github.com/uptycslabs/kspm-helm-charts/tree/main/charts/k8sosquery)
### K8sosquery
Helm charts for K8sosquery and Kubernetes resources required for it to function well in a cluster.
### [Kubequery](https://github.com/uptycslabs/kspm-helm-charts/tree/main/charts/kubequery)
### Kubequery
Helm charts for Kubequery and Kubernetes resources required for it to function well in a cluster.

## Usage
[Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

1. Download `values.yaml` files for K8sosquery & Kubequery from Uptycs UI. Downloaded file will be a tarball(.tar.gz) package.

> [!TIP]
> Tweak the appropriate fields in downloaded value files to enable or disable different features such as Uptycs Protect, Admission Controllers, and Detections on Audit Logs.

2. Add the Helm chart repository:
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

3. Perform Helm installation of K8sosquery & Kubequery:
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
