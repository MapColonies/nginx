#!/usr/bin/env python3
"""Inject a synthetic access-log record with chosen status and request_time.

Real local nginx answers in ~0.000s, so this is the only practical way to check that
latency lands in the right histogram bucket. The record mirrors nginx's syslog framing
(RFC3164) and the `main` log_format -- note request_time is a quoted *string*, exactly as
log_format.conf emits it.

Fluent Bit binds the syslog input to 127.0.0.1, so the datagram has to originate inside
nginx's network namespace; this runs itself in the nginx container via `docker compose exec`.

    ./send-access.py 502 1.7        # one record: status 502, request_time 1.7s
    ./send-access.py 404 0.25 5     # five of them
"""
import json
import subprocess
import sys
import time

status = sys.argv[1] if len(sys.argv) > 1 else "404"
request_time = sys.argv[2] if len(sys.argv) > 2 else "0.250"
count = int(sys.argv[3]) if len(sys.argv) > 3 else 1
port = sys.argv[4] if len(sys.argv) > 4 else "5514"

def build(sequence):
    """One record. `client.port` varies per record so a batch stays distinguishable: Loki drops
    a line that repeats an earlier one verbatim within the same second, and identical records
    would otherwise arrive as one."""
    return {
        "Timestamp": int(time.time() * 1_000_000_000),
        "Attributes": {
            "http.request.method": "GET",
            "http.response.status_code": status,
            "mapcolonies.request_time": request_time,
            "url.path": "/synthetic",
            "client.address": "10.0.0.1",
            "client.port": str(40000 + sequence),
        },
        "Resource": {"host.name": "synthetic", "service.name": "nginx"},
        "SeverityText": "INFO",
        "SeverityNumber": 9,
        "InstrumentationScope": "access.log",
        "Body": "GET /synthetic HTTP/1.1",
    }


# RFC3164 carries no timezone and Fluent Bit's syslog-rfc3164 parser reads the header as UTC,
# so the header must be UTC too -- nginx's own datagrams are (the container runs UTC). Using
# host local time instead skews every synthetic record by the host's offset, and a real backend
# then silently drops them: Loki rejects entries more than creation_grace_period (10m) ahead.
header = f"<190>{time.strftime('%b %d %H:%M:%S', time.gmtime())} synthetic nginx: "

# Each datagram travels as its own env var rather than inline in the shell script, so the JSON
# needs no shell quoting. busybox nc ships in the nginx image, so the stack needs no extra tooling.
env = []
sends = []
for i in range(count):
    env += ["-e", f"MSG{i}={header}{json.dumps(build(i), separators=(',', ':'))}"]
    sends.append(f"printf '%s' \"$MSG{i}\" | nc -u -w1 127.0.0.1 {port}")

result = subprocess.run(
    ["docker", "compose", "exec", "-T", *env, "nginx", "sh", "-c", "; ".join(sends)],
    capture_output=True,
    text=True,
)
if result.returncode != 0:
    sys.exit(f"send failed: {result.stderr.strip()}")
print(f"sent {count} record(s): status={status} request_time={request_time}")
