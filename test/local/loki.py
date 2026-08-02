#!/usr/bin/env python3
"""What reached the backend: print the records the sidecar forwarded, read back out of Loki.

This is the end of the pipeline. If a record is here, it survived every filter, was accepted
as OTLP, and is queryable the way it will be in production. `docker compose logs otel-collector`
is the complementary view -- the same records decoded field by field, before Loki.

Also importable: verify-forwarding.py asserts on `records()`.

    ./loki.py           # forwarded in the last 10 minutes
    ./loki.py 90        # ...in the last 90 seconds
"""
import json
import sys
import time
import urllib.parse
import urllib.request

LOKI = "http://localhost:3100"

# Everything the sidecar sends, whatever Loki ended up labelling it. Access records currently
# arrive with no resource attributes, so they land under `unknown_service` rather than `nginx`.
ALL_STREAMS = '{service_name=~".+"}'


def records(since_ns, query=ALL_STREAMS, limit=200):
    """Records Loki holds since `since_ns`, oldest first.

    Each is `{ts, labels, body}`. Access-log bodies are the decoded JSON envelope (a dict);
    error-log bodies are the message string. `labels` is what Loki indexed, which is where the
    error pipeline's level/client/request end up.
    """
    params = urllib.parse.urlencode(
        {"query": query, "start": str(since_ns), "limit": str(limit)}
    )
    with urllib.request.urlopen(f"{LOKI}/loki/api/v1/query_range?{params}") as response:
        payload = json.load(response)

    found = []
    for stream in payload["data"]["result"]:
        for ts, line in stream["values"]:
            body = json.loads(line) if line.startswith("{") else line
            found.append({"ts": int(ts), "labels": stream["stream"], "body": body})
    return sorted(found, key=lambda record: record["ts"])


def status(record):
    """HTTP status of an access record, or None for an error-log record."""
    body = record["body"]
    if isinstance(body, dict):
        return body.get("Attributes", {}).get("http.response.status_code")
    return None


def _format(record):
    stamp = time.strftime("%H:%M:%S", time.gmtime(record["ts"] / 1e9))
    body = record["body"]
    if isinstance(body, dict):
        attributes = body.get("Attributes", {})
        return "{}  access  {:>3}  {:<24} rt={}".format(
            stamp,
            attributes.get("http.response.status_code", "?"),
            attributes.get("url.path", "?"),
            attributes.get("mapcolonies.request_time", "?"),
        )
    labels = record["labels"]
    return "{}  error   {:<5}  {}  [{}]".format(
        stamp, labels.get("level", "?"), body, labels.get("request", "")
    )


if __name__ == "__main__":
    seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    found = records(time.time_ns() - seconds * 1_000_000_000)
    for record in found:
        print(_format(record))
    print(f"\n{len(found)} record(s) forwarded in the last {seconds}s (times UTC)")
