#!/usr/bin/env bash
# Render tests for the k8sosquery chart. Run: bash charts/k8sosquery/tests/render_test.sh
set -uo pipefail
CHART="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAILED=1; }
# render the daemonset template; extra args (e.g. -f values) are passed through
render() { helm template t "$CHART" -s templates/daemonset.yaml "$@"; }
# count rendered DaemonSets across all docs
ds_count() { render "$@" | yq ea '[select(.kind=="DaemonSet")] | length'; }
# value of a yq path for the (single) DaemonSet named $1
ds_get() { local name="$1"; shift; local path="$1"; shift; render "$@" \
  | yq ea "select(.kind==\"DaemonSet\" and .metadata.name==\"$name\") | $path"; }

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
[ "$(ds_get uptycs-osquery-default '.spec.template.spec.containers[0].resources.limits.memory' $V)" = "256Mi" ] \
  && pass "variants: default memory 256Mi" || fail "variants: default resources not applied"
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
  grep -q "must set a non-empty 'name'" err.txt && pass "validation: missing name errors clearly" || fail "validation: wrong/no message for missing name"
fi
if render -f "$CHART/tests/values-dupname.yaml" >/dev/null 2>err.txt; then
  fail "validation: duplicate name should fail render"
else
  grep -q "duplicate variant name" err.txt && pass "validation: duplicate name errors clearly" || fail "validation: wrong/no message for duplicate name"
fi
rm -f err.txt

echo "== values.yaml default still renders 1 DS (variants: []) =="
[ "$(ds_count)" = "1" ] && pass "values default: 1 DaemonSet" || fail "values default: expected 1, got $(ds_count)"

echo "== Task 5: variant pod-template label =="
[ "$(ds_get uptycs-osquery-high-memory '.spec.template.metadata.labels."uptycs.io/variant"' $V)" = "high-memory" ] \
  && pass "variants: high-memory pod-template label" || fail "variants: high-memory pod-template label missing/wrong"

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

[ "$FAILED" = "0" ] && echo "ALL PASS" || { echo "SOME FAILED"; exit 1; }
