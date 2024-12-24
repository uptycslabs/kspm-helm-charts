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
Get K8sosquery version from image tag
*/}}
{{- define "k8sosquery.version" -}}
{{- $osqueryChangeVersion := dict "0" 5 "1" 12 "2" 2 "3" 7 }}
{{- $imageTag := (split ":" .Values.daemonset.containers.image_name)._1 }}
{{- $versionString := (split "-" $imageTag)._0 }}
{{- $versionMap := split "." $versionString }}
{{- $isVersionGreater := false }}
{{- if or (gt (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (and (eq (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (gt (atoi $versionMap._1) (get $osqueryChangeVersion "1"))) (and (eq (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (eq (atoi $versionMap._1) (get $osqueryChangeVersion "1")) (gt (atoi $versionMap._2) (get $osqueryChangeVersion "2"))) (and (eq (atoi $versionMap._0) (get $osqueryChangeVersion "0")) (eq (atoi $versionMap._1) (get $osqueryChangeVersion "1")) (eq (atoi $versionMap._2) (get $osqueryChangeVersion "2")) (ge (atoi $versionMap._3) (get $osqueryChangeVersion "3"))) }}
{{- $isVersionGreater = true }}
{{- end }}
{{- $isVersionGreater -}}
{{- end }}