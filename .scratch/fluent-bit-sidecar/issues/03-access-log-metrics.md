Status: done

## Parent

`.scratch/fluent-bit-sidecar/spec.md`

## What to build

Extend the Fluent Bit ConfigMap (from slice 02) with a metrics pipeline that derives Prometheus metrics from the access-log stream and merges them with the existing `nginx-prometheus-exporter` metrics onto a single `/metrics` endpoint — satisfying the one-scrape-annotation constraint without any Prometheus-side change.

**Additions to the Fluent Bit ConfigMap (when `fluentbit.accessLog.metrics.enabled: true`):**

- `[INPUT] Name prometheus_scrape` — scrapes the existing `nginx-prometheus-exporter` at `localhost:<mclabels.prometheus.port-original>` (the exporter's own port, e.g. `9113`) and tags the series into the pipeline. Conditional on `fluentbit.accessLog.metrics.scrapeExporter: true`.
- `[FILTER] Name log_to_metrics` on tag `nginx.access` — the chart ships a default, overridable config block (rendered via `tpl`) containing:
  - A **counter** labelled by `status_code` (safe, bounded cardinality).
  - A **histogram** over the `request_time` field.
  - The raw block is the value of `fluentbit.accessLog.metrics.config`; operators can replace or extend it entirely.
- `[OUTPUT] Name prometheus_exporter` — serves the merged series (log-derived + scraped exporter) on `fluentbit.accessLog.metrics.port` (default `2021`) at `/metrics`. This is the port already wired to `mclabels.prometheus.port` by slice 01.

The `values.yaml` must include a documentation comment on `fluentbit.accessLog.metrics.config` warning operators **never** to label metrics by high-cardinality fields (URL path, query string, client IP, user-agent) to avoid OOMing the sidecar.

## Acceptance criteria

- [x] `fluentbit.accessLog.metrics.{enabled,scrapeExporter,port,config}` values exist with documented defaults.
- [x] When `metrics.enabled: false`, no `log_to_metrics` or `prometheus_exporter` blocks appear in the ConfigMap.
- [x] When `metrics.enabled: true` and `scrapeExporter: true`, a `prometheus_scrape` input block targeting the exporter's port is present.
- [x] When `metrics.enabled: true`, a `log_to_metrics` block is present; its content is the rendered value of `fluentbit.accessLog.metrics.config` (passed through `tpl`).
- [x] The default `metrics.config` value defines at least a per-status-code request counter and a `request_time` histogram.
- [x] An operator can override `metrics.config` with a custom raw block and the chart renders it without alteration (beyond `tpl` rendering).
- [x] A `prometheus_exporter` output block serves `/metrics` on `fluentbit.accessLog.metrics.port`.
- [x] The cardinality warning comment is present on the `metrics.config` key in `values.yaml`.
- [x] All new `values.yaml` keys carry helm-docs `-- ` annotation comments.

## Blocked by

- `.scratch/fluent-bit-sidecar/issues/02-access-log-forwarding-pipeline.md`

## Comments

- Implemented on branch `metrics-sidecar`.
  - `values.yaml`: added `fluentbit.accessLog.metrics.{enabled=true, scrapeExporter=true, config}` (`port` already existed), all with helm-docs `-- ` comments; `config` carries the high-cardinality warning plus a `@default` annotation. Default `config` ships a per-status-code counter (`nginx_http_requests_total{status_code}`) and a request-time histogram (`nginx_http_request_duration_seconds`). `values.md` rows added (alphabetical).
  - `config/fluent-bit.conf`: `prometheus_scrape` input (gated on `metrics.enabled && scrapeExporter`) targets `127.0.0.1:<mclabels.prometheus.port>` — the exporter's own port (9113); the `tpl`-rendered `metrics.config` `log_to_metrics` block sits **before** the grep filter so metrics count every request, not just the forwarded slice; `prometheus_exporter` output (gated on `metrics.enabled`) serves the merged series on `metrics.port` (2021) with `Match *` (Fluent Bit routes only metric events there, never logs). Also added a `fluentbit_metrics` self-monitoring input (records/bytes in/out, uptime) for sidecar sizing.
  - Field access uses record accessors (`$Attributes['...']`); confirmed against Fluent Bit source that `add_label` produces a clean `status_code` label and the histogram `value_field` coerces the JSON-string `request_time` via `sscanf`.
- Verified (chart-level only, per spec): disabled render byte-for-byte identical to baseline; `helm lint` passes enabled + disabled; `metrics.enabled=false` → no metric blocks; `scrapeExporter=false` → `prometheus_scrape` omitted, others present; operator `config` override renders through `tpl`. Runtime Fluent Bit behavior not chart-tested (out of scope by decision).
