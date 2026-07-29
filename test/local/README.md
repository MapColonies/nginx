# Local Fluent Bit sidecar harness

Runs the log-processing sidecar outside Kubernetes so the pipeline can be exercised in
seconds instead of through a deploy.

`fluent-bit` and `nginx-prometheus-exporter` join nginx's network namespace
(`network_mode: service:nginx`), which is what makes this faithful: `Listen 127.0.0.1`,
`access_log syslog:server=127.0.0.1` and the exporter scrape all behave exactly as they do
in a pod. A second Fluent Bit stands in for central Alloy's OTLP endpoint. nginx is built
from `docker-image/`, so it is the real image.

Configs are not copied here — `render.py` runs `helm template` and writes the ConfigMap
contents into `rendered/`, so the harness can never drift from the chart.

## Requirements

`docker compose`, `helm`, and `python3` with `pyyaml`.

## Run it

```sh
cd test/local
./render.py                    # chart -> rendered/
docker compose up -d --build   # first run builds the nginx image
```

Generate traffic:

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/            # site
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/nope        # 404
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081/nginx_status
```

Real local nginx always answers in ~0.000s and can only produce a couple of status codes, so
for latency and specific statuses inject a record directly:

```sh
./send-access.py 502 1.7      # status 502, request_time 1.7s
./send-access.py 404 0.25 5   # five records
```

Then look at the results:

```sh
curl -s http://localhost:2021/metrics | grep '^nginx_'  # merged /metrics
docker compose logs otlp-sink                           # what reached "Alloy"
docker compose logs fluent-bit                          # parse errors, crashes
docker compose logs nginx                               # access + error log
```

The merged endpoint carries both log-derived series and the scraped exporter's, so it is
worth checking that Prometheus would actually accept it — two families sharing a name make
it reject the whole scrape:

```sh
curl -s http://localhost:2021/metrics | \
  docker run --rm -i --entrypoint promtool prom/prometheus:v3.1.0 check metrics
```

Ignore `should have "_total" suffix` lint on `fluentbit_*` and `nginx_connections_*` (upstream
names, not ours); a `parsing error` is a real failure.

## Iterating

Changing chart values or `helm/config/fluent-bit.conf` means re-rendering and restarting the
container that reads it:

```sh
./render.py --set fluentbit.accessLog.exclude.enabled=true
docker compose restart fluent-bit   # nginx.conf / log_format.conf changes: restart nginx
```

Any arguments to `render.py` are passed through to `helm template`. Persistent overrides go
in `lab-values.yaml`, which already disables authorization and the route, and turns on 4xx
forwarding (the chart default is off).

Tear down with `docker compose down`.

## Seeing inside the pipeline

`fluentbit.debug` prints records to the sidecar's stdout. Filters print at their position in
the chain, so a record appearing at `parsed` but not in the output dump was removed by a
filter in between — which is how you find out *which* one:

```sh
./render.py --set fluentbit.debug.enabled=true --set fluentbit.debug.stages.received=true
docker compose restart fluent-bit
docker logs local-fluent-bit-1 2>/dev/null      # stdout only: the record dumps
docker logs local-fluent-bit-1 2>&1 1>/dev/null # stderr only: Fluent Bit's own log
```

## Worth knowing

- **To produce 5xx**, point nginx at a dead upstream:
  `./render.py --set backend.enabled=true --set backend.host=127.0.0.1 --set backend.port=9999`
  and restart both containers.
- **The kubelet liveness path is not logged at all** — `docker-image/nginx-config/status_site.conf`
  sets `access_log off` on `/nginx_status`, so it never reaches Fluent Bit and never appears
  in the derived metrics. `fluentbit.accessLog.exclude` is for probes that hit the main
  server instead.
- **`otlp-sink` does not show OTLP log attributes**, only the body. Access records arrive
  OTel-shaped and display fully, but the error pipeline's `level`/`client`/`request` fields
  are invisible here even though they are on the wire. To inspect them, point
  `fluentbit.output.logs.host` at a plain HTTP endpoint and read the raw payload.
- The `fluent/fluent-bit` tag in `docker-compose.yml` should track `fluentbit.image.tag` in
  `helm/values.yaml`; override per-run with `FLUENT_BIT_TAG=5.0.9 docker compose up -d`.
