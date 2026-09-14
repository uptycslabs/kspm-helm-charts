{{/*
Expand the name of the chart.
*/}}
{{- define "k8sosquery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "k8sosquery.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "k8sosquery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k8sosquery.labels" -}}
helm.sh/chart: {{ include "k8sosquery.chart" . }}
{{ include "k8sosquery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k8sosquery.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8sosquery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "k8sosquery.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k8sosquery.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Namespace identification
*/}}
{{- define "k8sosquery.namespace" -}}
{{- if (ne .Release.Namespace  "default") }}
  namespace: {{ .Release.Namespace }}
{{- else }}
  namespace: {{ .Values.namespace }}
{{- end }}
{{- end }}

{{/*
Get K8sosquery version from image tag.
Beginning K8sosquery version 5.12.2.7 the nginx cert path has been updated.
So this helper function is used to determine if the version present in image_tag is greater than or equal to the change version.
*/}}
{{- define "k8sosquery.version" -}}
{{- $osqueryChangeVersion := dict "0" 5 "1" 12 "2" 2 "3" 7 }}
{{- $imageTag := (split ":" .Values.daemonset.containers.image_name)._1 }}
{{- $versionString := (split "-" $imageTag)._0 }}
{{- $versionMap := split "." $versionString }}
{{- $isVersionGreaterOrEqual := false }}
{{- if or (gt (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (and (eq (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (gt (atoi $versionMap._1) (get $osqueryChangeVersion "1"))) (and (eq (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (eq (atoi $versionMap._1) (get $osqueryChangeVersion "1")) (gt (atoi $versionMap._2) (get $osqueryChangeVersion "2"))) (and (eq (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (eq (atoi $versionMap._1) (get $osqueryChangeVersion "1")) (eq (atoi $versionMap._2) (get $osqueryChangeVersion "2")) (ge (atoi $versionMap._3) (get $osqueryChangeVersion "3"))) }}
{{- $isVersionGreaterOrEqual = true }}
{{- end }}
{{- $isVersionGreaterOrEqual -}}
{{- end }}

{{/*
Add common labels for the chart resources specified in values
*/}}
{{- define "k8sosquery.commonLabels" -}}
{{- with .Values.commonLabels }}
  labels:
  {{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}


{{/*
Add common annotations for the chart resources specified in values
*/}}
{{- define "k8sosquery.commonAnnotations" -}}
{{- with .Values.commonAnnotations }}
  annotations:
  {{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}

{{/*
Add common labels for the chart resources specified in values for resources 
with existing labels
*/}}
{{- define "k8sosquery.appendCommonLabels" -}}
{{- with .Values.commonLabels -}}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}

{{/*
Add common annotations for the chart resources specified in values for resources
with existing annotations
*/}}
{{- define "k8sosquery.appendCommonAnnotations" -}}
{{- with .Values.commonAnnotations -}}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}

{{/*
Effective pod affinity for a DaemonSet: whatever the (merged) ds.affinity sets, plus a
required one-per-node podAntiAffinity keyed on app.kubernetes.io/name. Guarantees at most one
uptycs agent per node. Input: the effective ds map. Output: affinity YAML (always non-empty).
*/}}
{{- define "k8sosquery.mergedAffinity" -}}
{{- $affinity := deepCopy (.affinity | default dict) -}}
{{- $selfRule := dict "labelSelector" (dict "matchExpressions" (list (dict "key" "app.kubernetes.io/name" "operator" "In" "values" (list "uptycs-osquery")))) "topologyKey" "kubernetes.io/hostname" -}}
{{- $paa := get $affinity "podAntiAffinity" | default dict -}}
{{- $required := get $paa "requiredDuringSchedulingIgnoredDuringExecution" | default (list) -}}
{{- $required = append $required $selfRule -}}
{{- $_ := set $paa "requiredDuringSchedulingIgnoredDuringExecution" $required -}}
{{- $_ := set $affinity "podAntiAffinity" $paa -}}
{{- toYaml $affinity -}}
{{- end -}}

{{/*
Effective ConfigMap name for a variant: <base>-<variant> when the variant overrides the
configmap, else the shared base name. Input: dict "root" <$> "variant" <variant map or nil>.
*/}}
{{- define "k8sosquery.configmapName" -}}
{{- $base := .root.Values.configmap.name -}}
{{- if and .variant .variant.name -}}
{{- printf "%s-%s" $base .variant.name -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end -}}

{{/*
Recursively drop map keys whose value is null, then emit the map as YAML. Used after a variant
deep-merge so a variant override of `key: null` UNSETS the key - matching Helm's own values-layer
coalescing (a null in an override deletes the key) rather than leaving a literal `null` in the
manifest. Recurses into nested maps; lists are left as-is (variants replace lists wholesale).
Round-trip the result with `fromYaml` to get a map back. Input: a map (`.`).
*/}}
{{- define "k8sosquery.compact" -}}
{{- $out := dict -}}
{{- range $k, $v := . -}}
{{-   if kindIs "map" $v -}}
{{-     $_ := set $out $k (include "k8sosquery.compact" $v | fromYaml) -}}
{{-   else if not (kindIs "invalid" $v) -}}
{{-     $_ := set $out $k $v -}}
{{-   end -}}
{{- end -}}
{{- $out | toYaml -}}
{{- end -}}
