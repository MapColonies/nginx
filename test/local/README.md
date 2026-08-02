# Local Fluent Bit sidecar harness

Runs the log-processing sidecar outside Kubernetes, shipping into a real OTel backend, so the
pipeline can be exercised in seconds instead of through a deploy.

`fluent-bit` and `nginx-prometheus-exporter` join nginx's network namespace
(`network_mode: service:nginx`), which is what makes this faithful: `Listen 127.0.0.1`,
`access_log syslog:server=127.0.0.1` and the exporter scrape all behave exactly as they do in a
pod. nginx is built from `docker-image/`, so it is the real image. Forwarded records take the
production path — sidecar → OTLP/HTTP → `otel-collector` (standing in for central Alloy) → Loki.

Configs are not copied here — `render.py` runs `helm template` and writes the ConfigMap contents
into `rendered/`, so the harness can never drift from the chart.

## Requirements

`docker compose`, `helm`, and `python3` with `pyyaml`. First run pulls `grafana/otel-lgtm`
(3.3 GB on disk) and builds the nginx image.

## Run it

```sh
cd test/local
./render.py                    # chart -> rendered/
docker compose up -d --build
```

Generate traffic:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/            # site
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/nope        # 404
./send-access.py 502 1.7                                                   # 502, 1.7s
./send-access.py 404 0.25 5                                                # five records
```

Real local nginx always answers in ~0.000s and can only produce a couple of status codes, so
`send-access.py` injects a synthetic record for a specific status or latency. It mirrors nginx's
syslog framing and the `main` log_format, and sends from inside nginx's namespace.

## Look at the results

```sh
./loki.py                       # what was forwarded, read back out of Loki
docker compose logs otel-collector   # the same records decoded field by field, on the wire
curl -s http://localhost:2021/metrics | grep '^nginx_'   # merged /metrics
docker compose logs fluent-bit  # parse errors, crashes
docker compose logs nginx       # access + error log
```

`./loki.py` answers "did it get there"; the collector's `debug` exporter answers "in what
shape" — resource attributes, log attributes, severity and body, which is the only way to tell a
properly mapped OTLP record from one whose whole envelope was stuffed into the body. Grafana is
on <http://localhost:3000> for browsing the same data.

`./verify-forwarding.py` drives the whole `fluentbit.accessLog.forward` matrix: for each
combination it re-renders, restarts the sidecar, injects one record per status code, and asserts
which ones Loki actually holds.

The merged metrics endpoint carries both log-derived series and the scraped exporter's, so it is
worth checking that Prometheus would actually accept it — two families sharing a name make it
reject the whole scrape:

```sh
curl -s http://localhost:2021/metrics | \
  docker run --rm -i --entrypoint promtool prom/prometheus:v3.1.0 check metrics
```

Ignore `should have "_total" suffix` lint on `fluentbit_*` and `nginx_connections_*` (upstream
names, not ours); a `parsing error` is a real failure.

## Iterating

Changing chart values or `helm/config/fluent-bit.yaml` means re-rendering and restarting the
container that reads it:

```sh
./render.py --set fluentbit.accessLog.exclude.enabled=true
docker compose restart fluent-bit   # nginx.conf / log_format.conf changes: restart nginx
```

Any arguments to `render.py` are passed through to `helm template`. Persistent overrides go in
`lab-values.yaml`, which already disables authorization and the route, points the sidecar at
`otel-collector`, and turns on 4xx forwarding (the chart default is off).

The sidecar config is YAML, so Fluent Bit can check a render without running it — worth doing
before a restart, since a bad config crash-loops:

```sh
docker run --rm -v "$PWD/rendered/fluent-bit.yaml:/fluent-bit/etc/fluent-bit.yaml:ro" \
  fluent/fluent-bit:5.0.7 /fluent-bit/bin/fluent-bit --dry-run -c /fluent-bit/etc/fluent-bit.yaml
```

Tear down with `docker compose down`.

## Seeing inside the pipeline

`fluentbit.debug` prints records to the sidecar's stdout. Filters print at their position in the
chain, so a record appearing at `parsed` but not in the output dump was removed by a filter in
between — which is how you find out *which* one:

```sh
./render.py --set fluentbit.debug.enabled=true --set fluentbit.debug.stages.received=true
docker compose restart fluent-bit
docker logs local-fluent-bit-1 2>/dev/null      # stdout only: the record dumps
docker logs local-fluent-bit-1 2>&1 1>/dev/null # stderr only: Fluent Bit's own log
```

## Worth knowing

- **Access records are not mapped onto OTLP.** The whole nginx JSON envelope arrives as the log
  *body*, with no resource attributes — which is why `./loki.py` shows them under
  `unknown_service`. The error pipeline maps correctly. `docker compose logs otel-collector` is
  where the difference is visible.
- **To produce 5xx**, point nginx at a dead upstream:
  `./render.py --set backend.enabled=true --set backend.host=127.0.0.1 --set backend.port=9999`
  and restart both containers.
- **The kubelet liveness path is not logged at all** — `docker-image/nginx-config/status_site.conf`
  sets `access_log off` on `/nginx_status`, so it never reaches Fluent Bit and never appears in
  the derived metrics. `fluentbit.accessLog.exclude` is for probes that hit the main server.
- **Timestamps are UTC end to end.** RFC3164 syslog framing carries no timezone and Fluent Bit
  reads it as UTC, so a record stamped in a non-UTC local time lands in the future and Loki
  silently drops it (more than 10m ahead). The containers run UTC; `send-access.py` uses
  `gmtime` for the same reason.
- The `fluent/fluent-bit` tag in `docker-compose.yml` should track `fluentbit.image.tag` in
  `helm/values.yaml`; override per-run with `FLUENT_BIT_TAG=5.0.9 docker compose up -d`.
