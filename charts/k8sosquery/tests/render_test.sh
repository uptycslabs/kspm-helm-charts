#!/usr/bin/env bash
# Render tests for the k8sosquery chart. Run: bash charts/k8sosquery/tests/render_test.sh
set -uo pipefail
CHART="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAILED=1; }
# render the daemonset template; extra args (e.g. -f values) are passed through
render() { helm template t "$CHART" -s templates/daemonset.yaml "$@"; }
# render the configmap template; extra args (e.g. -f values) are passed through
cm() { helm template t "$CHART" -s templates/configmap.yaml "$@"; }
# count rendered DaemonSets across all docs
ds_count() { render "$@" | yq ea '[select(.kind=="DaemonSet")] | length'; }
# value of a yq path for the (single) DaemonSet named $1
ds_get() { local name="$1"; shift; local path="$1"; shift; render "$@" \
  | yq ea "select(.kind==\"DaemonSet\" and .metadata.name==\"$name\") | $path"; }
# value of a yq path for the (single) ConfigMap named $1
cm_get() { local name="$1"; shift; local path="$1"; shift; cm "$@" \
  | yq ea "select(.kind==\"ConfigMap\" and .metadata.name==\"$name\") | $path"; }
# does a ConfigMap with this name exist across all rendered docs
cm_exists() { local name="$1"; shift; cm "$@" \
  | yq ea "[select(.kind==\"ConfigMap\" and .metadata.name==\"$name\")] | length"; }

echo "== Task 1: refactor / backward-compat =="
[ "$(ds_count)" = "1" ] && pass "default: exactly 1 DaemonSet" || fail "default: expected 1 DaemonSet, got $(ds_count)"
[ "$(ds_get uptycs-osquery '.metadata.name')" = "uptycs-osquery" ] \
  && pass "default: name is uptycs-osquery" || fail "default: wrong name"
# selector must be EXACTLY {app.kubernetes.io/name: uptycs-osquery} (no variant label)
sel="$(ds_get uptycs-osquery '.spec.selector.matchLabels | keys | join(",")')"
[ "$sel" = "app.kubernetes.io/name" ] \
  && pass "default: selector unchanged" || fail "default: selector changed -> '$sel'"
[ "$(ds_get uptycs-osquery '.spec.template.spec.containers[0].name')" = "uptycs-osquery" ] \
  && pass "default: container present" || fail "default: container missing"
[ "$(ds_get uptycs-osquery '.spec.template.spec.hostPID')" = "true" ] \
  && pass "default: hostPID true" || fail "default: hostPID wrong"

echo "== helm lint =="
helm lint "$CHART" >/dev/null && pass "helm lint clean" || fail "helm lint failed"

echo "== Task 2: variants =="
V="-f $CHART/tests/values-variants.yaml"
[ "$(ds_count $V)" = "2" ] && pass "variants: exactly 2 DaemonSets" || fail "variants: expected 2, got $(ds_count $V)"
[ "$(ds_get uptycs-osquery-high-memory '.metadata.name' $V)" = "uptycs-osquery-high-memory" ] \
  && pass "variants: high-memory DS name" || fail "variants: missing uptycs-osquery-high-memory"
[ "$(ds_get uptycs-osquery-high-memory '.spec.selector.matchLabels."uptycs.io/variant"' $V)" = "high-memory" ] \
  && pass "variants: high-memory selector label" || fail "variants: high-memory selector label wrong"
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.spec.containers[0].resources.limits.memory' $V)" = "1Gi" ] \
  && pass "variants: high-memory memory 1Gi" || fail "variants: high-memory resources not applied"
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.spec.nodeSelector."node-pool"' $V)" = "high-memory" ] \
  && pass "variants: high-memory nodeSelector" || fail "variants: high-memory nodeSelector missing"
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.spec.tolerations[] | select(.value=="high-memory") | .key' $V)" = "dedicated" ] \
  && pass "variants: high-memory toleration" || fail "variants: high-memory toleration missing"
[ "$(ds_get uptycs-osquery-default '.spec.template.spec.containers[0].resources.limits.memory' $V)" = "500Mi" ] \
  && pass "variants: default inherits base memory 500Mi (no override)" || fail "variants: default resources not inherited"
# shared base still present in a variant (env inherited from base)
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.spec.hostPID' $V)" = "true" ] \
  && pass "variants: base hostPID inherited" || fail "variants: base not inherited"

echo "== Task 3: one-per-node anti-affinity =="
AA='.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0]'
[ "$(ds_get uptycs-osquery "$AA.topologyKey")" = "kubernetes.io/hostname" ] \
  && pass "default: anti-affinity topologyKey" || fail "default: anti-affinity missing"
[ "$(ds_get uptycs-osquery "$AA.labelSelector.matchExpressions[0].values[0]")" = "uptycs-osquery" ] \
  && pass "default: anti-affinity label selector" || fail "default: anti-affinity selector wrong"
# each variant also gets it
[ "$(ds_get uptycs-osquery-high-memory "$AA.topologyKey" -f $CHART/tests/values-variants.yaml)" = "kubernetes.io/hostname" ] \
  && pass "variants: high-memory anti-affinity present" || fail "variants: high-memory anti-affinity missing"
# MERGE: a user nodeAffinity is preserved AND anti-affinity is added
A="-f $CHART/tests/values-affinity.yaml"
[ "$(ds_get uptycs-osquery '.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key' $A)" = "kubernetes.io/os" ] \
  && pass "merge: user nodeAffinity preserved" || fail "merge: user nodeAffinity lost"
[ "$(ds_get uptycs-osquery "$AA.topologyKey" $A)" = "kubernetes.io/hostname" ] \
  && pass "merge: anti-affinity still injected" || fail "merge: anti-affinity dropped"

echo "== Task 4: variant validation =="
if render -f "$CHART/tests/values-badname.yaml" >/dev/null 2>err.txt; then
  fail "validation: missing name should fail render"
else
  grep -q "variants: every variant must set a non-empty 'name'" err.txt && pass "validation: missing name errors clearly" || fail "validation: wrong/no message for missing name"
fi
if render -f "$CHART/tests/values-dupname.yaml" >/dev/null 2>err.txt; then
  fail "validation: duplicate name should fail render"
else
  grep -q "variants: duplicate variant name" err.txt && pass "validation: duplicate name errors clearly" || fail "validation: wrong/no message for duplicate name"
fi
# 2+ variants: a variant with a daemonset override but no scheduling scope must fail
if render -f "$CHART/tests/values-unscoped.yaml" >/dev/null 2>err.txt; then
  fail "validation: unscoped variant (2+) should fail render"
else
  grep -q "must set daemonset.nodeSelector, daemonset.affinity, or daemonset.tolerations" err.txt \
    && pass "validation: unscoped variant errors clearly" || fail "validation: wrong/no message for unscoped variant"
fi
# 2+ variants scoped only by mutually-exclusive tolerations must be ACCEPTED (tolerations count)
if render -f "$CHART/tests/values-tolerations-scoped.yaml" >/dev/null 2>err.txt; then
  pass "validation: tolerations-only scoping accepted"
else
  fail "validation: tolerations-only scoping should NOT fail"
fi
rm -f err.txt

echo "== values.yaml default still renders 1 DS (variants: []) =="
[ "$(ds_count)" = "1" ] && pass "values default: 1 DaemonSet" || fail "values default: expected 1, got $(ds_count)"

echo "== Task 5: variant pod-template label =="
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.metadata.labels."uptycs.io/variant"' $V)" = "high-memory" ] \
  && pass "variants: high-memory pod-template label" || fail "variants: high-memory pod-template label missing/wrong"

echo "== Task 7: per-variant configmap (1-1 DaemonSet <-> ConfigMap) =="
# no variants -> exactly one base ConfigMap, mounted by the base DaemonSet
[ "$(cm_exists uptycs-config)" = "1" ] \
  && pass "configmap: no-variants renders single base uptycs-config" || fail "configmap: expected 1 base uptycs-config, got $(cm_exists uptycs-config)"
[ "$(ds_get uptycs-osquery '.spec.template.spec.volumes[] | select(.name=="config") | .configMap.name')" = "uptycs-config" ] \
  && pass "configmap: base DS mounts uptycs-config" || fail "configmap: base DS mounts wrong configmap"
# variants set -> one ConfigMap per variant, base name NOT rendered
[ "$(cm_get uptycs-config-high-memory '.data."osquery.tags"' $V)" = "role/high-memory" ] \
  && pass "configmap: uptycs-config-high-memory has variant tags" || fail "configmap: uptycs-config-high-memory missing/wrong tags"
[ "$(cm_exists uptycs-config $V)" = "0" ] \
  && pass "configmap: base uptycs-config NOT rendered when variants set" || fail "configmap: base uptycs-config should not render with variants"
[ "$(cm_exists uptycs-config-default $V)" -ge "1" ] \
  && pass "configmap: uptycs-config-default rendered (1-1, base data, no override)" || fail "configmap: uptycs-config-default missing"
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.spec.volumes[] | select(.name=="config") | .configMap.name' $V)" = "uptycs-config-high-memory" ] \
  && pass "configmap: high-memory DS mounts uptycs-config-high-memory" || fail "configmap: high-memory DS mounts wrong configmap"
[ "$(ds_get uptycs-osquery-default '.spec.template.spec.volumes[] | select(.name=="config") | .configMap.name' $V)" = "uptycs-config-default" ] \
  && pass "configmap: default DS mounts uptycs-config-default" || fail "configmap: default DS mounts wrong configmap"

echo "== Task 6: pre-existing podAntiAffinity preserved + appended =="
P="-f $CHART/tests/values-podantiaffinity.yaml"
paa_len="$(ds_get uptycs-osquery "$AA | length" $P)"
[ "$paa_len" = "2" ] \
  && pass "podAntiAffinity: user rule preserved and injected rule appended (len=2)" \
  || fail "podAntiAffinity: expected 2 entries, got $paa_len"
[ "$(ds_get uptycs-osquery ".spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[] | select(.topologyKey==\"kubernetes.io/hostname\") | .topologyKey" $P)" = "kubernetes.io/hostname" ] \
  && pass "podAntiAffinity: injected hostname rule present" || fail "podAntiAffinity: injected hostname rule missing"
[ "$(ds_get uptycs-osquery ".spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[] | select(.topologyKey==\"topology.kubernetes.io/zone\") | .topologyKey" $P)" = "topology.kubernetes.io/zone" ] \
  && pass "podAntiAffinity: user zone rule preserved" || fail "podAntiAffinity: user zone rule lost"

echo "== Task 8: null-prune (variant cpu: null unsets, like a values-layer override) =="
U="-f $CHART/tests/values-unset-cpu.yaml"
[ "$(ds_get uptycs-osquery-nolimit '.spec.template.spec.containers[0].resources.limits | has("cpu")' $U)" = "false" ] \
  && pass "unset: variant cpu:null removes the cpu limit key" || fail "unset: cpu limit still present after cpu:null"
[ "$(ds_get uptycs-osquery-nolimit '.spec.template.spec.containers[0].resources.limits.memory' $U)" = "1Gi" ] \
  && pass "unset: variant memory override still applied" || fail "unset: memory override missing"
[ "$(ds_get uptycs-osquery-nolimit '.spec.template.spec.containers[0].resources.requests.cpu' $U)" = "200m" ] \
  && pass "unset: base requests preserved (only the nulled key is dropped)" || fail "unset: base requests lost"

[ "$FAILED" = "0" ] && echo "ALL PASS" || { echo "SOME FAILED"; exit 1; }
