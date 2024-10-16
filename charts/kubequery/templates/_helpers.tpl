{{/*
Expand the name of the chart.
*/}}
{{- define "kubequery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubequery.fullname" -}}
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
{{- define "kubequery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubequery.labels" -}}
helm.sh/chart: {{ include "kubequery.chart" . }}
{{ include "kubequery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubequery.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubequery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubequery.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubequery.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Namespace identification
*/}}
{{- define "kubequery.namespace" -}}
{{- if (ne .Release.Namespace  "default") }}
  namespace: {{ .Release.Namespace }}
{{- else }}
  {{- if .Capabilities.APIVersions.Has "config.openshift.io/v1" }}
  namespace: {{ .Values.openshift.namespace.name }}
  {{- else }}
  namespace: {{ .Values.namespace }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Name identification for kubequery service
*/}}
{{- define "kubequery.svc.name" -}}
{{- if (ne .Release.Namespace  "default") }}
  name: kubequery-webhook.{{ .Release.Namespace }}.svc
{{- else }}
  {{- if .Capabilities.APIVersions.Has "config.openshift.io/v1" }}
  name: kubequery-webhook.{{ .Values.openshift.namespace.name }}.svc
  {{- else }}
  name: kubequery-webhook.{{ .Values.namespace }}.svc
  {{- end }}
{{- end }}
{{- end }}

{{/*
Name identification for kubequery gatekeeper service
*/}}
{{- define "kubequery.gk.svc.name" -}}
{{- if (ne .Release.Namespace  "default") }}
  name: kubequery-webhook-gatekeeper.{{ .Release.Namespace }}.svc
{{- else }}
  {{- if .Capabilities.APIVersions.Has "config.openshift.io/v1" }}
  name: kubequery-webhook-gatekeeper.{{ .Values.openshift.namespace.name }}.svc
  {{- else }}
  name: kubequery-webhook-gatekeeper.{{ .Values.namespace }}.svc
  {{- end }}
{{- end }}
{{- end }}

{{/*
Service account annotation for IRSA in AWS
*/}}
{{- define "kubequery.sa.irsa" -}}
{{- if (eq .Values.cloudProvider  "EKS")   }}
{{- if (not (empty .Values.IRSA)  )}}
  annotations:
     eks.amazonaws.com/role-arn : {{ .Values.IRSA }}
{{- end }}
{{- end }}
{{- end }}
