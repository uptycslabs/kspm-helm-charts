<!-- [![Lint Charts](https://github.com/hdsingh-uptycs/kspm-helm-charts/actions/workflows/lint-charts.yml/badge.svg?branch=main)](https://github.com/hdsingh-uptycs/kspm-helm-charts/actions/workflows/lint-charts.yml) -->
 
# Helm Chart Repository for Uptycs K8sosquery & Kubequery

Public Helm charts repository for Uptycs KSPM agents.

## Charts

<!-- ### [K8sosquery](https://github.com/hdsingh-uptycs/kspm-helm-charts/tree/main/charts/k8sosquery) -->
### K8sosquery
Helm charts for K8sosquery along with Kubernetes resources required for it to function well in a cluster.
<!-- ### [Kubequery](https://github.com/hdsingh-uptycs/kspm-helm-charts/tree/main/charts/kubequery) -->
### Kubequery
Helm charts for Kubequery along with Kubernetes resources required for it to function well in a cluster.

## Usage
[Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

1. Download the `values.yaml` files for k8sosquery & kubequery from Uptycs UI. Users will be able to download these files as a tarball(.tar.gz) package.

> Note: Tweak the appropriate fields in downloaded value files to enable or disable different features such as Uptycs Protect, Admission Controllers, and Detections on Audit Logs.

2. Add the Helm chart repository:
```bash
$ helm repo add kspm-helm-charts https://hdsingh-uptycs.github.io/kspm-helm-charts
```

> Note: If you've already added the helm repo, perform an update by running `helm repo update` to make sure you have the latest charts. You can then run `helm search repo kspm-helm-charts` to see the charts.

3. Perform Helm installation of k8sosquery & kubequery:
```bash
$ helm install k8sosquery -f <path_to_k8sosquery_values.yaml_file> kspm-helm-charts/k8sosquery
$ helm install kubequery -f <path_to_kubequery_values.yaml_file> kspm-helm-charts/kubequery --set deployment.spec.hostname=<cluster_name_in_uptycs_ui>
```

4. Verify installation of k8sosquery & kubequery:
```bash
$ kubectl get po -n uptycs
$ kubectl get po -n kubequery
```
