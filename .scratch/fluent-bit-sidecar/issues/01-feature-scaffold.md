Status: done

## Parent

`.scratch/fluent-bit-sidecar/spec.md`

## What to build

Add the `fluentbit.enabled` feature flag (off by default) to the chart and wire up everything that needs to change at the deployment and label level — with zero effect when the flag is false.

When `fluentbit.enabled: false` (the default), the chart must be byte-for-byte identical to today. When `fluentbit.enabled: true`:

- A Fluent Bit sidecar container is added to the Deployment. The image is sourced via the same `cloudProvider.dockerRegistryUrl` + `fluentbit.image.{repository,tag,pullPolicy}` convention used by `prometheusExporter.image`. Resources follow the same `enabled/value` shape.
- `mclabels.logScraping` is forced to `false` in the pod annotations (the central k8s-API collector must not ingest the full firehose). The user has no override.
- `mclabels.prometheus.port` is overridden to `fluentbit.accessLog.metrics.port` (default `2021`) so Prometheus discovery points at the merged Fluent Bit `/metrics` endpoint instead of the exporter's port.
- The existing `nginx-prometheus-exporter` container continues to run unchanged (it is kept by design — Fluent Bit will scrape it in a later slice).

Also fix the misleading comment on the exporter's `livenessProbe` in `deployment.yaml`: a container liveness failure restarts that container only, not the entire Pod.

Verifiable with `helm template`: default values produce output identical to today; `fluentbit.enabled=true` adds the sidecar container and changes the two mclabels annotations.

## Acceptance criteria

- [x] `fluentbit.enabled: false` is the default in `values.yaml`; existing users who upgrade see no change in rendered manifests.
- [x] `fluentbit.image.{repository,tag,pullPolicy}` values exist and follow the `prometheusExporter.image` convention.
- [x] `fluentbit.resources.{enabled,value}` exists with the same shape as `prometheusExporter.resources`.
- [x] When `fluentbit.enabled: true`, the Deployment gains a `fluent-bit` sidecar container using the configured image (prefixed with `cloudProvider.dockerRegistryUrl`).
- [x] When `fluentbit.enabled: true`, the pod annotation for `mclabels.logScraping` is unconditionally `false`.
- [x] When `fluentbit.enabled: true`, `mclabels.prometheus.port` is set to `fluentbit.accessLog.metrics.port` (default `2021`).
- [x] When `fluentbit.enabled: false`, `mclabels.logScraping` and `mclabels.prometheus.port` remain user-controlled (today's behavior).
- [x] The misleading liveness-probe comment on the exporter container is corrected.
- [x] All new `values.yaml` keys carry helm-docs `-- ` annotation comments.

## Blocked by

None — can start immediately.

## Comments

- Implemented in commit `48efe1a`. Verified via `helm template`: default render byte-for-byte identical apart from the exporter livenessProbe comment fix; `fluentbit.enabled=true` adds the `fluent-bit` sidecar, forces `mapcolonies.io/alloy-api-logs: "false"`, and advertises `prometheus.io/port: "2021"` while the exporter container/Service ports stay at `9113`. `helm lint` passes in both modes.
