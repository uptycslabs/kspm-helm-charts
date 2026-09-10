{{/*
Render one k8sosquery DaemonSet.
Context: dict "root" <$> "ds" <daemonset map> "variant" <name or "">.
variant "" = implicit default (legacy name, no uptycs.io/variant label).
*/}}
{{- define "k8sosquery.daemonset" -}}
{{- $root := .root -}}
{{- $ds := .ds -}}
{{- $variant := .variant -}}
{{- $name := $ds.name -}}
{{- if $variant }}{{- $name = printf "%s-%s" $ds.name $variant -}}{{- end -}}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ $name }}
  {{- include "k8sosquery.namespace" $root }}
  labels:
    {{- include "k8sosquery.appendCommonLabels" $root }}
    app.kubernetes.io/name: uptycs-osquery
    app.kubernetes.io/version: 1.0.0
    app.kubernetes.io/component: endpoint
    app.kubernetes.io/part-of: Uptycs
    {{- if $variant }}
    uptycs.io/variant: {{ $variant }}
    {{- end }}
  {{- include "k8sosquery.commonAnnotations" $root }}
spec:
  {{- with $ds.updateStrategy }}
  updateStrategy:
  {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      app.kubernetes.io/name: uptycs-osquery
      {{- if $variant }}
      uptycs.io/variant: {{ $variant }}
      {{- end }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: uptycs-osquery
        app.kubernetes.io/version: 1.0.0
        app.kubernetes.io/component: endpoint
        app.kubernetes.io/part-of: Uptycs
        {{- if $variant }}
        uptycs.io/variant: {{ $variant }}
        {{- end }}
      {{- with $ds.podAnnotations }}
      annotations:
      {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      serviceAccountName: uptycs-osquery
      {{- if $ds.priorityClassName }}
      priorityClassName: {{ $ds.priorityClassName }}
      {{- end }}
      {{- with $ds.tolerations }}
      tolerations:
      {{- toYaml . | nindent 6 }}
      {{- if $root.Capabilities.APIVersions.Has "config.openshift.io/v1" }}
      - key: node-role.kubernetes.io/infra
        effect: NoSchedule
      {{- end }}
      {{- end }}
      {{- with $ds.nodeSelector }}
      nodeSelector:
      {{- toYaml . | nindent 8 }}
      {{- end }}
      affinity:
        {{- include "k8sosquery.mergedAffinity" $ds | nindent 8 }}
      hostPID: true
      hostIPC: true
      hostNetwork: true
      {{- if $ds.dnsPolicy }}
      dnsPolicy: {{ $ds.dnsPolicy }}
      {{- end }}
      terminationGracePeriodSeconds: 30
      containers:
      - name: {{ $ds.containers.name }}
        image: {{ $ds.containers.image_name }}
        imagePullPolicy: {{ $ds.containers.pullPolicy }}
        {{- with $ds.containers.startupProbe }}
        startupProbe:
        {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $ds.containers.livenessProbe }}
        livenessProbe:
        {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $ds.containers.readinessProbe }}
        readinessProbe:
        {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- if eq $ds.dnsPolicy "ClusterFirstWithHostNet" }}
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "mount --bind /etc/resolv.conf /host/etc/resolv.conf"]
        {{- end }}
        {{- if eq $root.Values.isGKEAutopilot true }}
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
        {{- range $k, $v := $ds.containers.env }}
        - name: {{ $v.name }}
          value: {{ $v.value }}
        {{- end}}
        {{- with $ds.containers.resources }}
        resources:
        {{- toYaml . | nindent 10 }}
        {{- end }}
        volumeMounts:
        {{- range $k, $v := $ds.containers.volumeMounts }}
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
        {{- $isVersionGreaterOrEqual := include "k8sosquery.version" $root }}
        {{- if eq $isVersionGreaterOrEqual "true"}}
        - mountPath: /etc/osquery/cert
        {{- else }}
        - mountPath: /etc/osquery
        {{- end }}
          name: nginxsecret
          readOnly: true
      volumes:
      {{- range $k, $v := $ds.volumes }}
      - name: {{ $v.name }}
      {{- if hasKey $v "hostPath" }}
        hostPath:
          path: {{ $v.hostPath.path }}
      {{- end }}
      {{- if hasKey $v "secret" }}
        secret:
          secretName: {{ $v.secret.secretName }}
          {{- if hasKey $v.secret "optional"}}
          optional: {{ $v.secret.optional }}
          {{- end }}
      {{- end }}
      {{- end }}
      - name: config
        configMap:
          name: {{ .configmapName | default $root.Values.configmap.name }}
{{- end -}}
