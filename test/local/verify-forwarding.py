#!/usr/bin/env python3
"""End-to-end check that fluentbit.accessLog.forward selects the right records.

"Forwarded" means the record was read back out of Loki -- not that Fluent Bit claimed to send
it. For each case: re-render the chart with the case's values, restart the sidecar, inject one
synthetic record per status code, then ask Loki which of them arrived.

Needs the stack up (`docker compose up -d`). Leaves the render on the last case, so
re-run `./render.py` afterwards to get back to lab defaults.

    ./verify-forwarding.py
"""
import subprocess
import sys
import time

import loki

STATUSES = ["200", "404", "429", "502"]

# (name, extra `helm template` args, statuses expected to reach Loki)
CASES = [
    (
        "chart default: 5xx only",
        ["--set", "fluentbit.accessLog.forward.clientErrors=false"],
        {"502"},
    ),
    (
        "4xx + 5xx",
        ["--set", "fluentbit.accessLog.forward.clientErrors=true"],
        {"404", "429", "502"},
    ),
    (
        "5xx + explicit 429",
        [
            "--set", "fluentbit.accessLog.forward.clientErrors=false",
            "--set", "fluentbit.accessLog.forward.statusCodes[0]=429",
        ],
        {"429", "502"},
    ),
    (
        "no rule active: nothing forwarded",
        [
            "--set", "fluentbit.accessLog.forward.serverErrors=false",
            "--set", "fluentbit.accessLog.forward.clientErrors=false",
        ],
        set(),
    ),
]


def run(*command):
    subprocess.run(command, capture_output=True, text=True, check=True)


failures = []
for name, overrides, expected in CASES:
    run(sys.executable, "render.py", *overrides)
    run("docker", "compose", "restart", "fluent-bit")
    time.sleep(4)  # syslog inputs bound and ready

    start_ns = time.time_ns()
    for code in STATUSES:
        run(sys.executable, "send-access.py", code, "0.5")

    # Poll rather than sleep-and-hope: the nothing-forwarded case can only be judged on a
    # timeout, so give every case the same window before deciding.
    deadline = time.time() + 20
    arrived = set()
    while time.time() < deadline:
        arrived = {loki.status(r) for r in loki.records(start_ns)} - {None}
        if arrived == expected:
            break
        time.sleep(2)

    ok = arrived == expected
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    print(f"        expected {sorted(expected) or '(none)'}, got {sorted(arrived) or '(none)'}")
    if not ok:
        failures.append(name)

print()
print(f"{len(CASES) - len(failures)}/{len(CASES)} cases passed")
sys.exit(1 if failures else 0)
