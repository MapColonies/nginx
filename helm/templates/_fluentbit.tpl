{{/*
Fluent Bit sidecar container. Serves the merged Prometheus /metrics endpoint the pod
advertises when the feature is enabled. Its health never gates nginx.
*/}}
{{- define "nginx.fluentbitContainer" -}}
- name: fluent-bit
  {{- with .Values.fluentbit.image }}
  image: {{ include "nginx.cloudProviderDockerRegistryUrl" $ }}{{ .repository }}:{{ .tag }}
  {{- end }}
  imagePullPolicy: {{ .Values.fluentbit.image.pullPolicy }}
  volumeMounts:
    - name: fluentbit-config
      mountPath: /fluent-bit/etc/fluent-bit.conf
      subPath: fluent-bit.conf
  ports:
    - name: metrics
      containerPort: {{ .Values.fluentbit.accessLog.metrics.port }}
      protocol: TCP
  {{- if .Values.fluentbit.resources.enabled }}
  resources:
    {{- toYaml .Values.fluentbit.resources.value | nindent 4 }}
  {{- end }}
{{- end -}}
