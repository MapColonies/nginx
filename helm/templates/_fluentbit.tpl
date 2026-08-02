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
  # The image's default command points at the classic /fluent-bit/etc/fluent-bit.conf, so the
  # YAML config has to be named explicitly. Mounted next to the image's parsers.conf, which the
  # config loads by relative path.
  args: ["-c", "/fluent-bit/etc/fluent-bit.yaml"]
  volumeMounts:
    - name: fluentbit-config
      mountPath: /fluent-bit/etc/fluent-bit.yaml
      subPath: fluent-bit.yaml
    {{- if .Values.fluentbit.lua.enabled }}
    - name: fluentbit-config
      mountPath: /fluent-bit/scripts/custom.lua
      subPath: fluent-bit.lua
    {{- end }}
  ports:
    - name: metrics
      containerPort: {{ .Values.fluentbit.accessLog.metrics.port }}
      protocol: TCP
  {{- if .Values.fluentbit.resources.enabled }}
  resources:
    {{- toYaml .Values.fluentbit.resources.value | nindent 4 }}
  {{- end }}
{{- end -}}
