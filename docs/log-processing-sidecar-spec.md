# Spec: Optional Fluent Bit log-processing sidecar

## Problem Statement

We run nginx as a shared proxy chart across many workloads. Today every access log
line nginx writes to stdout is collected centrally, but we **do not have permission to
run a DaemonSet**, so log collection happens by reading pod logs through the
**Kubernetes API**. That path is expensive and throttled, and its cost scales with the
*total* stdout volume — so we pay, at high volume, to ingest a firehose of access logs
that is overwhelmingly routine `2xx`/`3xx` traffic we never look at.

We want to keep the small, valuable slice of logs (errors and specific status codes),
turn the log stream into useful metrics we can't get today, and stop paying to ship the
noise — and we need to cut that volume **as close to the source as possible**, because
the k8s-API collection path is the thing that costs us.

Separately, our metrics today come only from nginx `stub_status` via the
`nginx-prometheus-exporter` sidecar (connection/throughput counters). We have no
per-status-code rates and no latency distributions, and we have a general metrics-infra
constraint: Prometheus discovers targets by a **single scrape annotation per pod**, and
we have **no remote_write endpoint** we want to stand up and babysit.

## Solution

Add an **optional, off-by-default in-pod Fluent Bit sidecar** that becomes the pod's
single point of log egress and metrics exposure when enabled:

- nginx sends its full access/error log stream to Fluent Bit locally over **syslog UDP on
  loopback** (best-effort). nginx still writes to stdout/stderr for `kubectl logs`
  visibility, but the pod's central-collection scrape label is turned **off**, so the
  k8s-API collector no longer ingests the firehose — this is where the cost is cut.
- Fluent Bit **filters** the access logs down to errors / selected status codes and
  forwards only those to our **central Alloy over OTLP**; the rest are dropped.
- Fluent Bit **derives Prometheus metrics** from the same log stream (per-status-code
  request counter, request-time latency histogram) and **merges** them with the existing
  `stub_status` exporter's metrics onto a **single `/metrics` endpoint** it serves — so we
  keep connection gauges, gain the new metrics, and still expose exactly one scrape target
  with no Prometheus/remote_write change.

When the feature is disabled, the chart behaves exactly as it does today.

## User Stories

1. As a platform operator, I want the log-processing sidecar to be **off by default**, so
   that existing deployments of this chart are completely unaffected when they upgrade.
2. As a platform operator, I want a single `fluentbit.enabled` flag to turn the whole
   feature on, so that adopting it is one deliberate switch.
3. As a cost owner, I want the pod's central-collection scrape label forced **off** when
   the sidecar is enabled, so that we stop paying to ingest the full log firehose through
   the k8s API.
4. As a platform operator, I want to keep controlling the scrape label myself when the
   sidecar is **disabled**, so that today's behavior (logs collected as before) is
   preserved and under my control.
5. As an operator debugging a pod, I want nginx to keep writing logs to **stdout/stderr**
   even when the sidecar is on, so that `kubectl logs` still works for quick inspection.
6. As an operator reading `kubectl logs` on an enabled pod, I want stdout access logs in a
   **human-readable** format (not raw JSON), so that they are easy to scan by eye.
7. As an operator, I want that human-readable stdout line to include the metadata we
   already surface — notably the authenticated **client name** — plus request time and
   upstream status, so that the readable log is actually useful and not a bare access line.
8. As a log consumer, I want the JSON-structured access log (our existing OTel-shaped
   format) to flow to Fluent Bit over the syslog path, so that downstream tooling still
   receives fully structured records.
9. As an SRE, I want Fluent Bit to forward only **server errors (5xx)** by default, so that
   incident-relevant logs reach Loki without me configuring anything.
10. As an SRE, I want to also opt into forwarding **client errors (4xx)** with a boolean,
    so that I can include them when they matter to me.
11. As an SRE, I want to specify an explicit **list of extra status codes** to forward
    (e.g. `429`, `499`), so that I can capture specific conditions beyond the error classes.
12. As an SRE, I want everything not matched by my forwarding rules to be **dropped** by
    the sidecar, so that only the valuable slice leaves the pod.
13. As an SRE, I want the forwarding rules expressed as **simple structured values**, so
    that I don't have to learn Fluent Bit's config language for the common case.
14. As an observability engineer, I want Fluent Bit to derive a **per-status-code request
    counter** from the access logs, so that I can chart request and error rates by status.
15. As an observability engineer, I want a **request-time latency histogram** derived from
    the access logs, so that I can compute p50/p95/p99 latency that `stub_status` cannot
    provide.
16. As an observability engineer, I want those metric definitions provided as an
    **overridable default** set with safe, bounded cardinality, so that the feature is
    useful the moment it's enabled and demonstrates the safe pattern.
17. As an advanced observability engineer, I want to supply my **own raw metric
    definitions** (as Fluent Bit config code blocks) to derive additional metrics, so that
    I'm not limited to the defaults.
18. As an advanced user, I want my raw metrics/config blocks rendered through Helm **`tpl`**,
    so that I can reference chart values and release info inside them.
19. As an observability engineer, I want to be warned (in docs) never to label metrics by
    high-cardinality fields (path, query, client IP, user-agent), so that I don't OOM the
    sidecar or overload Prometheus.
20. As a Prometheus operator, I want Fluent Bit to also **scrape the existing
    `nginx-prometheus-exporter`** and re-expose its metrics, so that `stub_status`
    connection gauges are preserved.
21. As a Prometheus operator, I want Fluent Bit to serve **one merged `/metrics`** endpoint
    (log-derived + scraped exporter), so that the single-scrape-annotation limit is
    satisfied with no Prometheus change.
22. As a Prometheus operator, I want the pod's advertised scrape port (`mclabels.prometheus.port`)
    to automatically point at Fluent Bit's merged endpoint when the feature is enabled, so
    that discovery just works.
23. As a Prometheus operator, I want to make **no remote_write change** to Prometheus, so
    that I don't have to stand up and monitor a new ingestion path.
24. As an SRE, I want nginx **error logs** also shipped through Fluent Bit on a separate
    pipeline, so that error output is captured alongside access logs.
25. As an SRE, I want error logs parsed into **structured fields** (level, pid, message,
    client, request) by Fluent Bit, so that they are queryable even though nginx OSS emits
    them as plaintext.
26. As an SRE, I want **all** error logs at/above a configurable level forwarded (no
    status-based filtering, since error logs have no status), so that I don't lose error
    context.
27. As an SRE, I want error logs to reach the **same central OTLP logs endpoint** as access
    logs, so that they land together and are sorted by severity downstream.
28. As a developer, I want a simple mechanism to **mount a custom Lua script** (rendered
    through `tpl`) into Fluent Bit, so that I can implement advanced filtering (e.g. latency
    thresholds) later without changing the chart.
29. As a reliability owner, I want the sidecar's failure to **never affect nginx** — nginx
    must not block on the sidecar and its liveness must not depend on it — so that log
    processing can never take down serving traffic.
30. As a reliability owner, I accept that logs are **best-effort** (datagrams may drop under
    load or while the sidecar restarts), so that we get source-side volume reduction without
    coupling nginx's fate to a log file or a reliable transport.
31. As a platform operator, I want the Fluent Bit image sourced and pinned the **same way as
    the existing exporter image** (repository/tag/pullPolicy via `cloudProvider`), so that
    it fits our registry and pull-secret conventions.
32. As a platform operator, I want the Fluent Bit configuration delivered via a
    **ConfigMap** rendered through `tpl`, consistent with how the chart already ships
    `nginx.conf`/`log_format.conf`.
33. As a platform operator, I want a dedicated, explicit **OTLP logs endpoint** value
    (not reusing the traces `opentelemetry.exporterHost`), so that logs go to the correct
    Alloy receiver.
34. As a chart maintainer, I want the existing `nginx-prometheus-exporter` to remain in
    place (coexist), so that we don't lose connection-level signal and don't destabilize the
    current metrics path.

## Implementation Decisions

**Tool selection — Fluent Bit.** Chosen over Grafana Alloy and the OpenTelemetry Collector.
Deciding factors, given locked constraints (scrape-only, single scrape annotation, keep
`stub_status` gauges, cut volume at source):
- Fluent Bit is the only candidate that can **merge** externally-scraped metrics
  (`prometheus_scrape` input) with log-derived metrics (`log_to_metrics`) onto **one**
  `prometheus_exporter` `/metrics` endpoint — Alloy's `/metrics` cannot re-expose scraped
  series (it is push-only for those, requiring remote_write, which is out of scope), and the
  OTel Collector has **no logs→histogram** capability at all.
- Fluent Bit's `log_to_metrics` supports **counter, gauge, and histogram** (including a
  histogram over a numeric log field such as `request_time`).
- Lightest footprint of the three (C; ~20–30 MB) — relevant across a fleet of pods.
- Accepted trade-offs: it is not our existing org-standard agent (Alloy), and advanced
  numeric filtering needs Lua — but the common status-based forwarding compiles to a plain
  `grep` regex and needs no Lua.

**Metrics egress model — scrape only, no remote_write.** Fluent Bit serves a single merged
`/metrics`. No change to Prometheus. Alloy-with-push was explicitly rejected because it is
the heaviest option and the only one requiring a new push endpoint we'd have to operate.

**Coexistence with `nginx-prometheus-exporter`.** The exporter stays. Fluent Bit scrapes it
via `prometheus_scrape` and re-exposes its series alongside the log-derived metrics. When
the feature is enabled, `mclabels.prometheus.port` advertises **Fluent Bit's** merged port
instead of the exporter's port, so exactly one endpoint is scraped.

**Transport — syslog over UDP loopback.** nginx emits its logs to Fluent Bit via
`access_log syslog:server=127.0.0.1:<accessPort>` and `error_log syslog:server=127.0.0.1:<errorPort>`.
UDP loopback was chosen over a unix domain socket because (a) it has no socket-file
startup-ordering dependency, and (b) it survives Fluent Bit restarts cleanly, whereas a
unix *datagram* socket suffers a stale-inode problem after the receiver recreates the socket
(persistent silent loss until an nginx reload). File-tailing was **rejected**: a shared log
file couples nginx's availability to disk pressure and to the sidecar keeping up — trading a
data-loss risk for an availability risk, which is unacceptable.

**Loss model — best-effort, observable enough.** Datagram syslog is fire-and-forget; the
kernel drops when the receive buffer fills (e.g. during a burst). This is accepted. We will
size the receive buffer to reduce drops and rely on rough signals (UDP drop counters and/or
comparing nginx's request count against Fluent Bit's received count) to know when to scale
the sidecar. No elaborate drop-accounting is built.

**Failure isolation.** Fluent Bit runs as a **regular sidecar container** (Kubernetes 1.24
does not support native/`restartPolicy: Always` sidecars). Its health never gates nginx:
nginx never blocks on it (UDP is non-blocking), and Fluent Bit's liveness at most restarts
its own container. The existing exporter's liveness-probe comment ("the entire Pod … will
restart") is misleading — a liveness failure restarts only that container — and will be
revisited/cleaned up, not treated as a mandate.

**Two nginx log destinations, format depends on feature state.**
- Feature **disabled** (today): access log → stdout as **JSON** (our existing
  `log_format ... escape=json` template), collected as before. There is **no** native JSON
  log format in open-source nginx; the manual `escape=json` template remains the approach.
- Feature **enabled**: access log → **stdout in a human-readable format** (combined-style,
  augmented with the authenticated client name `$jwt_payload_sub`, `request_time`, and
  upstream status) for `kubectl logs`, **and** → **syslog (JSON)** for Fluent Bit. Error log
  → **stderr (plaintext)** for humans **and** → **syslog (plaintext)** for Fluent Bit.

**Scrape-label wiring.** When `fluentbit.enabled=true`, the chart **forces** the
central-collection scrape label (`mclabels.logScraping` → `mapcolonies.io/alloy-api-logs`)
to `false`, with **no override**. When disabled, the label remains user-controlled with
today's default. This removes the double-ingest footgun.

**Access-log forwarding — structured knobs → `grep`.** Chart-authored values compile to a
single Fluent Bit `grep` filter on the status field:
- `clientErrors: bool` (keep `4xx`), `serverErrors: bool` (keep `5xx`), `statusCodes: []`
  (extra explicit codes). Because HTTP status is always three digits, these map to a clean
  regex (e.g. `^[45]` for errors, alternation for explicit codes) — **no Lua** needed.
- Everything unmatched is dropped. Latency-threshold forwarding is **not** in scope (it would
  require Lua) but is enabled later via the Lua escape hatch.

**Metrics config — bounded defaults + raw passthrough.** The chart ships a default,
overridable `log_to_metrics` set with **safe, bounded cardinality**: a per-`status_code`
request counter and a `request_time` histogram (optionally split by method). Advanced users
supply **raw** Fluent Bit config blocks for additional metrics. Both the raw metrics config
and the Lua script are rendered through **`tpl`**. There is no hard cardinality enforcement
(impossible with raw config); docs warn against high-cardinality labels.

**Error-log pipeline — separate, plaintext, structured in Fluent Bit.** A distinct syslog
input on its own port and Fluent Bit **tag** (`nginx.error` vs `nginx.access`), parsed by a
**regex parser** the chart ships for the standard nginx error format
(`time [level] pid#tid: *cid message, client:…, server:…, request:"…"`), yielding structured
fields. Forwarding policy is **forward-all at/above a configurable `minLevel`** (no
status-based filtering). Native JSON error logs (`error_log … json`, nginx 1.29.8) are
**NGINX Plus-only** and unavailable on the open-source `-otel` image, so plaintext + Fluent
Bit parsing is the approach. **No error-log metrics** are shipped by default; because metrics
config is tag-matched, a user can add error metrics later purely in raw config with no chart
change.

**Log egress — OTLP to central Alloy.** Both pipelines forward via Fluent Bit's
`opentelemetry` output (OTLP/HTTP) to a **dedicated logs endpoint** (`fluentbit.output.logs.*`),
explicitly **not** the traces-only `opentelemetry.exporterHost`. Loki push is not used — the
central Alloy already accepts OTLP and owns the Loki backend.

**Config delivery & image.** Fluent Bit config (inputs, filters, parsers, metrics, outputs,
optional Lua script) is delivered via a **ConfigMap rendered with `tpl`**, mirroring how
`nginx.conf`/`log_format.conf`/`default.conf` are shipped. The image follows the
`prometheusExporter.image` convention (`repository`/`tag`/`pullPolicy`, registry prefixed via
`cloudProvider`).

**Proposed `values.yaml` shape (illustrative, from the design discussion):**

```yaml
fluentbit:
  enabled: false                 # off by default; when true → forces scrape label off
  image:
    repository: common/fluent-bit
    tag: "3.x"
    pullPolicy: IfNotPresent
  resources: { enabled: true, value: { ... } }
  output:
    logs:                        # dedicated OTLP logs endpoint (NOT opentelemetry.exporterHost)
      host: ""
      port: 4318
      protocol: http
  accessLog:
    syslogPort: 5514
    stdoutReadable: true         # human-readable stdout when enabled; JSON goes to syslog
    forward:
      clientErrors: false        # keep 4xx
      serverErrors: true         # keep 5xx
      statusCodes: []            # extra explicit codes, e.g. [429, 499]
    metrics:
      enabled: true
      scrapeExporter: true       # prometheus_scrape the nginx exporter → merge
      port: 2021                 # single merged /metrics → mclabels.prometheus.port when enabled
      config: |                  # raw log_to_metrics blocks (tpl-rendered); safe defaults shipped
        # per-status counter + request_time histogram
  errorLog:
    enabled: true
    syslogPort: 5515
    minLevel: warn               # forward all at/above this level
  lua:
    enabled: false
    script: |                    # inline Lua, tpl-rendered, mounted for advanced filtering
      # function keep(tag, ts, record) ... end
```

## Testing Decisions

Automated tests are **out of scope by decision** — this repo has no test harness and the
team opted not to introduce one for this feature. Verification is manual, via `helm template`
against representative value sets (enabled/disabled, each forwarding knob, Lua on/off) to
confirm the rendered Deployment, ConfigMap, and `mclabels` labels/annotations match the
decisions above. Runtime behavior of nginx and Fluent Bit (actual datagram delivery,
filtering, drop behavior under load) is not asserted by any chart-level test and would only
be observed in a live environment.

## Out of Scope

- **Automated tests** (per decision above).
- **Remote_write / metrics push** and any Prometheus-side configuration change — explicitly
  rejected; scrape-only is the model.
- **Grafana Alloy or OpenTelemetry Collector** as the sidecar — evaluated and not chosen.
- **File-tail / stdout-tail ingestion** — rejected as a production-availability risk.
- **Latency-threshold (numeric) forwarding rules** — not shipped as structured knobs;
  achievable later via the Lua escape hatch.
- **Error-log-derived metrics** — not shipped by default (achievable via raw tag-matched
  config).
- **Loki push protocol** — egress is OTLP only.
- **Native JSON error logs** — an NGINX Plus feature, unavailable on the open-source image.
- **Guaranteed / lossless log delivery** — the design is explicitly best-effort.
- **Native/`restartPolicy: Always` sidecars** — unavailable on Kubernetes 1.24.
- **Publishing this spec to the issue tracker** — created as a local file only.

## Further Notes

- **Primary success metric:** reduction in log volume ingested through the k8s-API
  collection path once the scrape label is turned off and only filtered logs egress via
  Fluent Bit.
- **Validation items flagged during design** (confirm during implementation, not blockers):
  - **Datagram size:** access-log JSON can be large (long URLs/query strings); oversized
    UDP datagrams may be truncated/dropped, causing a parse failure and line loss. Size the
    receive buffer accordingly and confirm typical line sizes fit.
  - Confirm the exact nginx directive/behavior for combining `error_log syslog:` with the
    chosen output, and the standard error-format regex, on the pinned image.
- **Cluster/version context:** target is Kubernetes **1.24** (no native sidecars); nginx base
  image is the open-source `nginxinc/nginx-unprivileged:1.29.8-alpine3.23-otel`.
- **Docs:** the chart's `values.md` is generated by helm-docs (CI); new values will need the
  documentation-comment annotations the chart already uses.
- **Publishing blocked at time of writing:** `gh` auth token is invalid and the issue-tracker
  triage-label vocabulary was not available; if this spec is later pushed to the tracker,
  apply the `ready-for-agent` label.
