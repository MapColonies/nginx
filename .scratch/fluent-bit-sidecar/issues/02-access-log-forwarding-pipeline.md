Status: done

## Parent

`.scratch/fluent-bit-sidecar/spec.md`

## What to build

Wire up the full access-log path from nginx through Fluent Bit to central Alloy: nginx gets a conditional second log destination (syslog UDP to the sidecar), and Fluent Bit's ConfigMap is created with a syslog input, a status-based grep filter, and an OTLP output.

**nginx log-format changes (conditional on `fluentbit.enabled`):**

- When disabled (today): access log → stdout as JSON. No change.
- When enabled: access log → stdout in a **human-readable format** (combined-log-style, augmented with `$jwt_payload_sub`, `$request_time`, and upstream status) for `kubectl logs` visibility, **and** → syslog UDP (`127.0.0.1:fluentbit.accessLog.syslogPort`, default `5514`) in JSON (the existing OTel-shaped format) for Fluent Bit. Both destinations are active simultaneously. The nginx `access_log syslog:…` directive must use a format that produces the existing JSON structure.

**New Fluent Bit ConfigMap** (`<release>-fluentbit-configmap`):

- `[INPUT] Name syslog` listening on `fluentbit.accessLog.syslogPort` (UDP), tagging records `nginx.access`.
- `[FILTER] Name grep` compiling `fluentbit.accessLog.forward.{serverErrors, clientErrors, statusCodes}` into a single regex on the `status` field:
  - `serverErrors: true` → match `^5`
  - `clientErrors: true` → match `^4`
  - explicit `statusCodes` entries → exact alternation (e.g. `429|499`)
  - Combined as `^(5|4|429|499)` — everything else is dropped.
  - If no rule is active the filter still drops everything (no logs escape unless at least one rule matches).
- `[OUTPUT] Name opentelemetry` forwarding matched records to `fluentbit.output.logs.{host,port,protocol}` (dedicated OTLP logs endpoint, not `opentelemetry.exporterHost`).

The ConfigMap is rendered via `tpl` consistent with how the existing nginx configmap works. The Fluent Bit container from slice 01 mounts this ConfigMap.

## Acceptance criteria

- [x] `fluentbit.accessLog.syslogPort` (default `5514`) and `fluentbit.accessLog.stdoutReadable` (default `true`) exist in `values.yaml`.
- [x] `fluentbit.accessLog.forward.{serverErrors,clientErrors,statusCodes}` values exist (defaults: `serverErrors: true`, `clientErrors: false`, `statusCodes: []`).
- [x] `fluentbit.output.logs.{host,port,protocol}` values exist (host required/empty, port `4318`, protocol `http`).
- [x] When `fluentbit.enabled: false`, `log_format.conf` / nginx config is unchanged from today.
- [x] When `fluentbit.enabled: true`, the nginx config includes a human-readable stdout log format augmented with `$jwt_payload_sub`, `$request_time`, and upstream status.
- [x] When `fluentbit.enabled: true`, the nginx config includes an `access_log syslog:server=127.0.0.1:<port>` directive emitting the existing JSON format.
- [x] A Fluent Bit ConfigMap is rendered when `fluentbit.enabled: true` and absent when false.
- [x] The grep filter regex correctly encodes the combination of `serverErrors`, `clientErrors`, and `statusCodes` values.
- [x] Records not matched by any forwarding rule are dropped (not forwarded).
- [x] The OTLP output uses `fluentbit.output.logs.*`, not `opentelemetry.exporterHost`.
- [x] The Fluent Bit container from slice 01 mounts the ConfigMap.
- [x] All new `values.yaml` keys carry helm-docs `-- ` annotation comments.

## Blocked by

- `.scratch/fluent-bit-sidecar/issues/01-feature-scaffold.md`

## Comments

- Implemented on branch `metrics-sidecar`. Changes:
  - `values.yaml`: added `fluentbit.output.logs.{host,port,protocol}` (host `""`, port `4318`, protocol `http`), `fluentbit.accessLog.{syslogPort=5514, stdoutReadable=true}`, and `fluentbit.accessLog.forward.{serverErrors=true, clientErrors=false, statusCodes=[]}`, all with helm-docs `-- ` comments; regenerated `values.md` rows.
  - `config/nginx.conf`: the `access_log` directive is now conditional on `fluentbit.enabled`. Disabled → unchanged (`main` to stdout). Enabled → stdout gets `readable` (or `main` when `stdoutReadable=false`) **and** a second `access_log syslog:server=127.0.0.1:<syslogPort> main` line ships the JSON format to Fluent Bit. Kept inline so the disabled render is byte-for-byte identical (verified via `helm template` diff).
  - `config/log_format.conf`: added a `readable` combined-style format (only emitted when enabled) augmented with `$jwt_payload_sub` (guarded on `authorization.enabled`, matching the `js_set`), `$request_time`, and `$upstream_status`.
  - New `config/fluent-bit.conf` (tpl-rendered) + `templates/fluentbit-configmap.yaml` (`<release>-nginx-fluentbit-configmap`, gated on `enabled`): syslog UDP input on `127.0.0.1:<syslogPort>` tagged `nginx.access`, grep filter compiling the forward knobs into a single regex, and an `opentelemetry` output to `fluentbit.output.logs.*` (`Tls On` when protocol is `https`).
  - `_helpers.tpl`: `nginx.fluentbit.accessLogRegex` compiles `serverErrors→5`, `clientErrors→4`, and each `statusCodes` entry into `^(a|b|...)`; when no rule is active it emits `^$` (matches only empty), so every real status is dropped.
  - `deployment.yaml` + `_fluentbit.tpl`: added the `fluentbit-config` volume and mounted it at `/fluent-bit/etc/fluent-bit.conf` (subPath), both gated on `enabled`.
- **Deviation from the literal three-section list:** the grep matches on the nested OTel status field via record accessor `$Attributes['http.response.status_code']`, which requires the JSON body be decoded first — so a fourth section, a `parser` filter (`Parser json`, `Reserve_Data On`), was added before grep. It relies on the `json` parser from the image's default `parsers.conf` (left intact by the subPath mount).
- Verification (per spec, chart-level only): `helm lint` passes enabled + disabled; disabled render byte-for-byte identical to pre-change baseline; regex matrix confirmed — defaults `^(5)`, server+client+`[429,499]` → `^(5|4|429|499)`, all-off → `^$`, only `[418]` → `^(418)`; ConfigMap present when enabled and absent when disabled; sidecar mounts the ConfigMap. Runtime datagram/OTLP behavior is not chart-tested (out of scope).
