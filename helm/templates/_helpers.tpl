{{/*
Expand the name of the chart.
*/}}
{{- define "nginx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nginx.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nginx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
mclabels labels. When Fluent Bit is enabled, force the log-scraping label off so the
central k8s-API collector stops ingesting the firehose. Override is set on a deep copy,
so the shared .Values is never mutated. (`merge` can't be used here: mergo treats the
`false` override as empty and keeps the original value.)
*/}}
{{- define "nginx.mclabels.labels" -}}
{{- $mclabels := .Values.mclabels -}}
{{- if .Values.fluentbit.enabled -}}
{{- $mclabels = set (deepCopy .Values.mclabels) "logScraping" false -}}
{{- end -}}
{{- include "mclabels.labels" (dict "Values" (dict "mclabels" $mclabels "global" .Values.global)) -}}
{{- end -}}

{{/*
mclabels annotations. When Fluent Bit is enabled, point the advertised Prometheus port at
its merged /metrics endpoint. The override is set on a deep copy, so the exporter
container and Service keep using the exporter's own port. Unlike the labels helper, no
`global` is threaded through — mclabels.annotations reads only .Values.mclabels.
*/}}
{{- define "nginx.mclabels.annotations" -}}
{{- $mclabels := .Values.mclabels -}}
{{- if .Values.fluentbit.enabled -}}
{{- $prometheus := set (deepCopy .Values.mclabels.prometheus) "port" .Values.fluentbit.accessLog.metrics.port -}}
{{- $mclabels = set (deepCopy .Values.mclabels) "prometheus" $prometheus -}}
{{- end -}}
{{- include "mclabels.annotations" (dict "Values" (dict "mclabels" $mclabels)) -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "nginx.labels" -}}
helm.sh/chart: {{ include "nginx.chart" . }}
{{ include "nginx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "nginx.mclabels.labels" . }}
{{- end }}

{{/*
Returns the tag of the chart.
*/}}
{{- define "nginx.tag" -}}
{{- default (printf "v%s" .Chart.AppVersion) .Values.image.tag }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nginx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- include "mclabels.selectorLabels" . }}
{{- end }}

{{/*
Returns the environment from global if exists or from the chart's values, defaults to development
*/}}
{{- define "nginx.environment" -}}
{{- if .Values.global.environment }}
    {{- .Values.global.environment -}}
{{- else -}}
    {{- .Values.environment | default "development" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the cloud provider name from global if exists or from the chart's values, defaults to minikube
*/}}
{{- define "nginx.cloudProviderFlavor" -}}
{{- if .Values.global.cloudProvider.flavor }}
    {{- .Values.global.cloudProvider.flavor -}}
{{- else if .Values.cloudProvider -}}
    {{- .Values.cloudProvider.flavor | default "minikube" -}}
{{- else -}}
    {{ "minikube" }}
{{- end -}}
{{- end -}}

{{/*
Returns the cloud provider docker registry url from global if exists or from the chart's values
*/}}
{{- define "nginx.cloudProviderDockerRegistryUrl" -}}
{{- if .Values.global.cloudProvider.dockerRegistryUrl }}
    {{- printf "%s/" .Values.global.cloudProvider.dockerRegistryUrl -}}
{{- else if .Values.cloudProvider.dockerRegistryUrl -}}
    {{- printf "%s/" .Values.cloudProvider.dockerRegistryUrl -}}
{{- else -}}
{{- end -}}
{{- end -}}

{{/*
Returns the cloud provider image pull secret name from global if exists or from the chart's values
*/}}
{{- define "nginx.cloudProviderImagePullSecretName" -}}
{{- if .Values.global.cloudProvider.imagePullSecretName }}
    {{- .Values.global.cloudProvider.imagePullSecretName -}}
{{- else if .Values.cloudProvider.imagePullSecretName -}}
    {{- .Values.cloudProvider.imagePullSecretName -}}
{{- end -}}
{{- end -}}

{{/*
    Create a list of subPaths off the extraVolumeMounts in order to prevent conflict
    with user's subPaths list
*/}}
{{- define "listOfSubPaths" -}}
    {{- $subPathsList := list -}}
    {{- range .Values.extraVolumeMounts -}}
        {{- $subPathsList = append $subPathsList .subPath -}}
    {{- end -}}
    {{ toJson $subPathsList }}
{{- end -}}

{{/*
Generate OpenTelemetry ratio sampler split_clients block
*/}}
{{- define "nginx.otelRatioSampler" -}}
split_clients "$otel_trace_id" $ratio_sampler {
              {{ .Values.opentelemetry.ratio }}%              on;
              *                off;
}
{{- end -}}

{{/*
Generate OpenTelemetry trace configuration
*/}}
{{- define "nginx.otelTrace" -}}
{{- if eq .Values.opentelemetry.samplerMethod "AlwaysOn" -}}
otel_trace on;
{{- else if eq .Values.opentelemetry.samplerMethod "TraceIdRatioBased" -}}
otel_trace $ratio_sampler;
{{- else -}}
otel_trace off;
{{- end -}}
otel_trace_context propagate;
{{- end -}}
