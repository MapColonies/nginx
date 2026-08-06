{{/*
Fluent Bit sidecar container. The merged /metrics port is declared only when
accessLog.metrics.enabled — the prometheus_exporter output is gated on the same value, so
declaring it unconditionally would advertise a port with nothing serving it.
*/}}
{{- define "nginx.fluentbit.container" -}}
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
  {{- if .Values.fluentbit.accessLog.metrics.enabled }}
  ports:
    - name: metrics
      containerPort: {{ .Values.fluentbit.accessLog.metrics.port }}
      protocol: TCP
  {{- end }}
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

{{/*
One OTLP/HTTP logs output, parameterised by the tag it matches (dict: ctx, match). Both
pipelines ship to the same dedicated central Alloy logs endpoint (fluentbit.output.logs.*,
deliberately NOT the traces-only opentelemetry.exporterHost), and the Lua filters put access
and error records in the same envelope — so the two outputs differ only in that tag.
*/}}
{{- define "nginx.fluentbit.logsOutput" -}}
{{- $ := .ctx -}}
- name: opentelemetry
  match: {{ .match }}
  host: {{ include "nginx.fluentbit.logsHost" $ | quote }}
  port: {{ $.Values.fluentbit.output.logs.port }}
  logs_uri: /v1/logs
  # The Lua filter leaves the nginx `Body` field as the only body candidate; naming it keeps the
  # output from shipping the whole record as the log body.
  logs_body_key: $Body
  {{- if eq $.Values.fluentbit.output.logs.protocol "https" }}
  tls: on
  {{- end }}
  {{- include "nginx.fluentbit.logsProcessors" $ | nindent 2 }}
{{- end -}}

{{/*
Compile the access-log forwarding rules (fluentbit.accessLog.forward) into a single regex
for Fluent Bit's grep filter, matched against the HTTP status code. serverErrors adds 5xx
(`5`), clientErrors adds 4xx (`4`), and each explicit statusCodes entry is added verbatim; a
status matches when it starts with any alternative (e.g. `^(5|429)`). When no rule is active
the regex is `^$`, which matches only an empty string — so every real (non-empty) status is
dropped and nothing is forwarded.
*/}}
{{- define "nginx.fluentbit.accessLogRegex" -}}
{{- $parts := list -}}
{{- if .Values.fluentbit.accessLog.forward.serverErrors -}}
{{- $parts = append $parts "5" -}}
{{- end -}}
{{- if .Values.fluentbit.accessLog.forward.clientErrors -}}
{{- $parts = append $parts "4" -}}
{{- end -}}
{{- range .Values.fluentbit.accessLog.forward.statusCodes -}}
{{- $parts = append $parts (toString .) -}}
{{- end -}}
{{- if $parts -}}
^({{ join "|" $parts }})
{{- else -}}
^$
{{- end -}}
{{- end -}}

{{/*
The central Alloy OTLP logs host. Required whenever the sidecar is enabled — an empty
value renders a Fluent Bit config that crash-loops on startup, so fail the release
instead with a message that names the value to set.
*/}}
{{- define "nginx.fluentbit.logsHost" -}}
{{- required "fluentbit.output.logs.host is required when fluentbit.enabled is true — set it to the central Alloy OTLP logs endpoint" .Values.fluentbit.output.logs.host -}}
{{- end -}}
