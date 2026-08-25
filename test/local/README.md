# Local Fluent Bit sidecar harness

Runs the log-processing sidecar outside Kubernetes so the pipeline can be exercised in seconds
instead of through a deploy.

`fluent-bit` and `nginx-prometheus-exporter` join nginx's network namespace
(`network_mode: service:nginx`), which is what makes this faithful: `Listen 127.0.0.1`,
`access_log syslog:server=127.0.0.1` and the exporter scrape all behave exactly as they do in a
pod. nginx is built from `docker-image/`, so it is the real image.

Configs are not copied here — `render.py` runs `helm template` and writes the ConfigMap contents
into `rendered/`, so the harness can never drift from the chart.

Records take the production path out of the sidecar (OTLP/HTTP), to one of two backends:

- **`otel-collector`** (the default) stands in for central Alloy. It prints every record fully
  decoded and dumps it as OTLP JSON into `logs/out.json` — the fast loop, no query language.
- **`lgtm`** is a real Loki/Prometheus/Grafana stack, for when you want to browse the data the
  way a person would in production.

## Requirements

`docker compose`, `helm`, and `python3` with `pyyaml`. First run pulls `grafana/otel-lgtm`
(~1.5 GB) and builds the nginx image.

## Run it

```sh
cd test/local
./render.py                    # chart -> rendered/
docker compose up -d --build
```

## Send logs

Anything nginx answers produces an access record, and a 404 produces an error record too:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/            # 200
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/nope        # 404 + error log
```

Only the status codes selected by `fluentbit.accessLog.forward` are forwarded —
`lab-values.yaml` turns on 4xx and 5xx, so the 404 arrives at the backend and the 200 does not.
Every request feeds the derived metrics regardless.

## View them

```sh
tail -f logs/out.json                            # what was forwarded, as OTLP JSON
docker compose logs -f otel-collector            # the same records decoded field by field
curl -s http://localhost:2021/metrics | grep '^nginx_'   # merged /metrics
docker compose logs fluent-bit                   # per-filter record dumps, parse errors, crashes
docker compose logs nginx                        # access + error log
```

`logs/out.json` answers "did it get there"; the collector's `debug` exporter answers "in what
shape" — resource attributes, log attributes, severity and body, which is the only way to tell a
properly mapped OTLP record from one whose whole envelope was stuffed into the body.

`logs/out.json` is append-only and gitignored; `rm logs/out.json` between runs when a clean
slate matters (the collector recreates it).

### In Grafana instead

Point the sidecar at lgtm and query Loki on <http://localhost:3000>:

```sh
./render.py --set fluentbit.output.logs.host=lgtm
docker compose restart fluent-bit
```

## Iterating

Changing chart values or `helm/config/fluent-bit.yaml` means re-rendering and restarting the
container that reads it:

```sh
./render.py --set fluentbit.accessLog.exclude.enabled=true
docker compose restart fluent-bit   # nginx.conf / log_format.conf changes: restart nginx
```

Any arguments to `render.py` are passed through to `helm template`. Persistent overrides go in
`lab-values.yaml`, which already disables authorization and the route, points the sidecar at
`otel-collector`, states the 4xx/5xx forwarding selection explicitly and enables
`fluentbit.debug`, whose `stdout` filters are what make `docker compose logs fluent-bit` show
each record at its position in the filter chain — a record appearing at `parsed` but not in the
output dump was removed by a filter in between.

The sidecar config is YAML, so Fluent Bit can check a render without running it — worth doing
before a restart, since a bad config crash-loops:

```sh
docker run --rm -v "$PWD/rendered/fluent-bit.yaml:/fluent-bit/etc/fluent-bit.yaml:ro" \
  fluent/fluent-bit:5.0.7 /fluent-bit/bin/fluent-bit --dry-run -c /fluent-bit/etc/fluent-bit.yaml
```

Tear down with `docker compose down`.

## Worth knowing

- **To produce 5xx**, point nginx at a dead upstream:
  `./render.py --set backend.enabled=true --set backend.host=127.0.0.1 --set backend.port=9999`
  and restart both containers.
- **The kubelet liveness path is not logged at all** — `docker-image/nginx-config/status_site.conf`
  sets `access_log off` on `/nginx_status`, so it never reaches Fluent Bit and never appears in
  the derived metrics. `fluentbit.accessLog.exclude` is for probes that hit the main server.
- **Timestamps are UTC end to end.** RFC3164 syslog framing carries no timezone and Fluent Bit
  reads it as UTC, so a record stamped in a non-UTC local time lands in the future and Loki
  silently drops it (more than 10m ahead). The containers run UTC.
- **The merged /metrics carries two families**, log-derived and scraped, so it is worth checking
  that Prometheus would accept it — two families sharing a name make it reject the whole scrape:
  `curl -s http://localhost:2021/metrics | docker run --rm -i --entrypoint promtool
  prom/prometheus:v3.1.0 check metrics`. Ignore `should have "_total" suffix` lint on
  `nginx_connections_*` (an upstream name, not ours); a `parsing error` is real.
- `POD_UID` stands in for the downward API and defaults to all zeroes; set it per-run to see a
  real `k8s.pod.uid` resource attribute.
- The `fluent/fluent-bit` tag in `docker-compose.yml` should track `fluentbit.image.tag` in
  `helm/values.yaml`; override per-run with `FLUENT_BIT_TAG=5.0.9 docker compose up -d`.
