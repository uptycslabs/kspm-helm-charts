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
Render a single nodeSelectorTerm that excludes nodes matching ANY of the given other node
groups' nodeSelectors. Takes a list of single-key nodeSelector maps (one per other group).
Each entry contributes one NotIn matchExpression, all AND'd together within this one term --
by De Morgan's law, "NOT(matches group B) AND NOT(matches group C) AND ..." is exactly what's
needed to keep a group's DaemonSet off every other group's nodes, and that only collapses to a
single flat term because each group's nodeSelector is constrained to exactly one key (enforced
by the caller). Used by templates/daemonset-nodegroups.yaml.
*/}}
{{- define "k8sosquery.excludeOtherGroupsAffinity" -}}
- matchExpressions:
  {{- range . }}
  {{- range $key, $value := . }}
  - key: {{ $key }}
    operator: NotIn
    values:
    - {{ $value | quote }}
  {{- end }}
  {{- end }}
{{- end }}

{{/*
Render the K8sosquery container spec (the single-element `containers:` list, including probes,
security context, env, resources and volumeMounts). Shared by templates/daemonset.yaml and
templates/daemonset-nodegroups.yaml so the two don't drift out of sync.
Takes a dict: "global" (the root template context, i.e. `.` or `$`) and "resources" (the
resources map to render for this container -- the default daemonset.containers.resources for the
single-DaemonSet path, or a per-node-group merged map for the multi-node-group path).
*/}}
{{- define "k8sosquery.containers" -}}
containers:
- name: {{ .global.Values.daemonset.containers.name }}
  image: {{ .global.Values.daemonset.containers.image_name }}
  imagePullPolicy: {{ .global.Values.daemonset.containers.pullPolicy }}
  {{- with .global.Values.daemonset.containers.startupProbe }}
  startupProbe:
  {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .global.Values.daemonset.containers.livenessProbe }}
  livenessProbe:
  {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .global.Values.daemonset.containers.readinessProbe }}
  readinessProbe:
  {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if eq .global.Values.daemonset.dnsPolicy "ClusterFirstWithHostNet" }}
  lifecycle:
    postStart:
      exec:
        command: ["/bin/sh", "-c", "mount --bind /etc/resolv.conf /host/etc/resolv.conf"]
  {{- end }}
  {{- if eq .global.Values.isGKEAutopilot true }}
  securityContext:
    capabilities:
      add:
        - SYS_ADMIN
        - BPF
        - PERFMON
        - PTRACE
        - NET_ADMIN
        - NET_RAW
        - SYS_CHROOT
        - FOWNER
        - SYS_RESOURCE
  {{- else }}
  securityContext:
    privileged: true
  {{- end }}
  env:
  {{- range $k, $v := .global.Values.daemonset.containers.env }}
  - name: {{ $v.name }}
    value: {{ $v.value }}
  {{- end}}
  resources:
  {{- toYaml .resources | nindent 4 }}
  volumeMounts:
  {{- range $k, $v := .global.Values.daemonset.containers.volumeMounts }}
  - name: {{ $v.name }}
  {{- if hasKey $v "mountPath" }}
    mountPath: {{ $v.mountPath }}
  {{- end }}
  {{- if hasKey $v "readOnly" }}
    readOnly: {{ $v.readOnly }}
  {{- end}}
  {{- if hasKey $v "mountPropagation" }}
    mountPropagation: {{ $v.mountPropagation }}
  {{- end }}
  {{- end }}
  {{- $isVersionGreaterOrEqual := include "k8sosquery.version" .global }}
  # Beginning K8sosquery version 5.12.2.7 the nginx cert path has been updated so the below statement checks for that
  {{- if eq $isVersionGreaterOrEqual "true"}}
  - mountPath: /etc/osquery/cert
  {{- else }}
  - mountPath: /etc/osquery
  {{- end }}
    name: nginxsecret
    readOnly: true
{{- end }}