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
    # The chart's Lua filter, next to the config; the optional user script gets its own path.
    - name: fluentbit-config
      mountPath: /fluent-bit/etc/metadata.lua
      subPath: metadata.lua
    {{- if .Values.fluentbit.lua.enabled }}
    - name: fluentbit-config
      mountPath: /fluent-bit/scripts/custom.lua
      subPath: fluent-bit.lua
    {{- end }}
  # Read as the k8s.pod.uid resource attribute by the OTLP output.
  env:
    - name: POD_UID
      valueFrom:
        fieldRef:
          fieldPath: metadata.uid
  ports:
    - name: metrics
      containerPort: {{ .Values.fluentbit.accessLog.metrics.port }}
      protocol: TCP
  {{- if .Values.fluentbit.resources.enabled }}
  resources:
    {{- toYaml .Values.fluentbit.resources.value | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
`processors` block for an OTLP logs output: the only place a record's resource attributes can be
set (filters can never reach them, so without this everything arrives as `unknown_service`).
`opentelemetry_envelope` must come first — it puts the record in the OTLP shape that gives
content_modifier an `otel_resource_attributes` context. Values mirror the `Resource` block of
config/log_format.conf, which the Lua filter strips from the body. `${VAR}` is left unquoted so
Fluent Bit's parser expands it.
*/}}
{{- define "nginx.fluentbit.logsProcessors" -}}
processors:
  logs:
    - name: opentelemetry_envelope
    - name: content_modifier
      context: otel_resource_attributes
      action: upsert
      key: service.name
      value: {{ .Values.nameOverride | default "nginx" | quote }}
    - name: content_modifier
      context: otel_resource_attributes
      action: upsert
      key: service.version
      value: {{ include "nginx.tag" . | quote }}
    - name: content_modifier
      context: otel_resource_attributes
      action: upsert
      key: host.name
      value: ${HOSTNAME}
    - name: content_modifier
      context: otel_resource_attributes
      action: upsert
      key: k8s.pod.uid
      value: ${POD_UID}
{{- end -}}
