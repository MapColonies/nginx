Status: done

## Parent

`.scratch/fluent-bit-sidecar/spec.md`

## What to build

Extend the chart to ship nginx error logs through Fluent Bit: a second syslog UDP destination for nginx's error output, a dedicated Fluent Bit pipeline that parses the plaintext nginx error format into structured fields, applies a severity level filter, and forwards to the same central OTLP logs endpoint as the access-log pipeline.

**nginx error-log changes (conditional on `fluentbit.errorLog.enabled`):**

When enabled, the nginx config adds `error_log syslog:server=127.0.0.1:<errorLog.syslogPort>` in addition to the default stderr output, so both destinations are active simultaneously and `kubectl logs` is unaffected.

Native JSON error logs (`error_log … json`) are an NGINX Plus feature unavailable on the open-source image; this slice uses plaintext + Fluent Bit parsing.

**Additions to the Fluent Bit ConfigMap (when `fluentbit.errorLog.enabled: true`):**

- `[INPUT] Name syslog` on `fluentbit.errorLog.syslogPort` (default `5515`, UDP), tagging records `nginx.error`.
- `[PARSER]` for the standard nginx error format: `time [level] pid#tid: *cid message, client: …, server: …, request: "…"` — yielding fields `level`, `pid`, `message`, `client`, `server`, `request`. The chart ships this parser definition.
- `[FILTER] Name grep` on tag `nginx.error` dropping records below `fluentbit.errorLog.minLevel` (default `warn`). Severity ordering: `debug < info < notice < warn < error < crit < alert < emerg`.
- `[OUTPUT] Name opentelemetry` forwarding matched records to the same `fluentbit.output.logs.*` endpoint used by the access-log pipeline.

The two pipelines (`nginx.access` and `nginx.error`) are tag-isolated; the error pipeline has no effect on access-log forwarding or metrics.

## Acceptance criteria

- [ ] `fluentbit.errorLog.{enabled,syslogPort,minLevel}` values exist (defaults: `enabled: true`, `syslogPort: 5515`, `minLevel: warn`).
- [ ] When `fluentbit.errorLog.enabled: false`, no error-log syslog directive appears in the nginx config and no `nginx.error` blocks appear in the Fluent Bit ConfigMap.
- [ ] When `fluentbit.errorLog.enabled: true`, the nginx config includes `error_log syslog:server=127.0.0.1:<errorLog.syslogPort>` alongside the existing stderr output.
- [ ] The Fluent Bit ConfigMap includes the nginx error-format parser definition when the error pipeline is enabled.
- [ ] The syslog input for error logs uses a distinct port (`errorLog.syslogPort`) and tag (`nginx.error`) from the access-log input.
- [ ] The severity-level grep filter drops records below `minLevel`; records at or above `minLevel` are forwarded.
- [ ] Matched error-log records are forwarded to `fluentbit.output.logs.*` (same endpoint as access logs).
- [ ] The error pipeline has no effect on access-log forwarding or metrics (tag isolation confirmed via `helm template`).
- [ ] All new `values.yaml` keys carry helm-docs `-- ` annotation comments.

## Blocked by

- `.scratch/fluent-bit-sidecar/issues/02-access-log-forwarding-pipeline.md`

## Comments

- Implemented on branch `metrics-sidecar`. Changes:
  - `values.yaml`: added `fluentbit.errorLog.{enabled=true, syslogPort=5515, minLevel=warn}` with helm-docs `-- ` comments; `values.md` rows added (alphabetical).
  - `config/nginx.conf`: added a conditional second `error_log syslog:server=127.0.0.1:<syslogPort> <minLevel>;` directive (gated on `fluentbit.enabled && errorLog.enabled`), alongside the existing file/stderr `error_log`. Disabled render is byte-for-byte identical to baseline (verified).
  - `config/fluent-bit.conf`: error pipeline gated on `errorLog.enabled` — syslog UDP `[INPUT]` on `errorLog.syslogPort` tagged `nginx.error` (distinct from the access input), a parser `[FILTER]` decoding the plaintext line via the shipped `nginx_error` parser, and an `opentelemetry` `[OUTPUT]` (`Match nginx.error`) to the same `fluentbit.output.logs.*` endpoint as the access pipeline (`Tls On` when https). Added `parsers_file fluent-bit-parsers.conf` to `[SERVICE]`.
  - New `config/fluent-bit-parsers.conf`: ships the `nginx_error` regex parser (fields `level`, `pid`, `message`, `client`, `server`, `request` + optional `time`). Shipped as a second ConfigMap data key and mounted into the sidecar at `/fluent-bit/etc/fluent-bit-parsers.conf` (both gated on `errorLog.enabled`).
- **Deviation from AC (user-approved):** severity filtering is done **natively at nginx** (`error_log ... <minLevel>`) rather than via a Fluent Bit `grep` filter. Rationale: severity is first-class in nginx, so a grep would be redundant parse-then-drop work and extra UDP/sidecar load; filtering at the source also reduces UDP pressure on the records we keep. This preserves the AC's intent (forward records at/above `minLevel`, drop the rest). Consequence: `minLevel` must be a valid nginx severity token — the value's doc comment lists the exact set (debug…emerg); `debug` needs a debug-enabled nginx build (OSS image floors at `info`).
- **Regex validation:** the `nginx_error` parser was checked against representative lines (full request error, message containing a comma, worker/startup line with no connection id, and a syslog-stripped line with no leading timestamp) — all parse correctly; a comma inside the message does not truncate the `client/server/request` tail (matched as a unit).
- Verification (chart-level only, per spec — no test harness): `helm lint` passes disabled + enabled (errorLog on/off); disabled render byte-for-byte identical to baseline; `errorLog.enabled=false` emits no error blocks / parser key / mount / nginx syslog directive; `minLevel` and `syslogPort` overrides propagate; tag isolation confirmed (`nginx.error` blocks never match `nginx.access`). Runtime datagram/OTLP behavior is not chart-tested (out of scope).
