Status: ready-for-agent

## Parent

`.scratch/fluent-bit-sidecar/spec.md`

## What to build

Add a mount point for a custom Lua script in the Fluent Bit access-log pipeline, allowing operators to implement advanced filtering (e.g. latency-threshold forwarding) without any chart change. The script is an inline value rendered through `tpl`, stored as a key in the Fluent Bit ConfigMap, and mounted into the sidecar container.

When `fluentbit.lua.enabled: true`:

- The inline `fluentbit.lua.script` value (rendered through `tpl`) is added as a `fluent-bit.lua` key in the Fluent Bit ConfigMap.
- A `[FILTER] Name lua` block is inserted in the access-log pipeline (after the status grep filter, before the OTLP output) referencing the mounted script file.
- The Fluent Bit container gets a volumeMount for the ConfigMap key at a fixed path (e.g. `/fluent-bit/scripts/custom.lua`).

When `fluentbit.lua.enabled: false` (the default), no Lua key, no Lua filter block, and no volumeMount are rendered.

The script is tpl-rendered, so operators can reference `{{ .Release.Name }}`, chart values, etc. inside it.

## Acceptance criteria

- [ ] `fluentbit.lua.{enabled,script}` values exist (defaults: `enabled: false`, `script: ""`).
- [ ] When `lua.enabled: false`, no Lua-related keys, filter blocks, or volumeMounts appear in any rendered manifest.
- [ ] When `lua.enabled: true`, the `fluent-bit.lua` key is present in the Fluent Bit ConfigMap and contains the tpl-rendered `lua.script` value.
- [ ] When `lua.enabled: true`, a `[FILTER] Name lua` block appears in the ConfigMap after the grep filter and before the OTLP output for the `nginx.access` tag.
- [ ] When `lua.enabled: true`, the Fluent Bit container has a volumeMount projecting the `fluent-bit.lua` ConfigMap key to a deterministic path.
- [ ] A `tpl` reference (e.g. `{{ .Release.Name }}`) inside `lua.script` is correctly resolved in `helm template` output.
- [ ] All new `values.yaml` keys carry helm-docs `-- ` annotation comments.

## Blocked by

- `.scratch/fluent-bit-sidecar/issues/02-access-log-forwarding-pipeline.md`

## Comments

- **Scope narrowed to mount-only (operator decision during implementation).** The chart now
  only makes the script available — it adds the `fluent-bit.lua` ConfigMap key (tpl-rendered)
  and mounts it at `/fluent-bit/scripts/custom.lua`. It does **not** auto-insert a
  `[FILTER] Name lua` block, and there is no `lua.call` value. The operator supplies their own
  filter block referencing the mounted path. This drops the "auto-inserted filter block" and
  "call" acceptance criteria in favour of a simpler, unopinionated mount. Values shipped:
  `fluentbit.lua.{enabled,script}` only.
