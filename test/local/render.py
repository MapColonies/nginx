#!/usr/bin/env python3
"""Render the chart with lab-values.yaml and write every ConfigMap key into ./rendered/.

The harness always tests exactly what the chart produces, so there are no hand-maintained
copies of nginx.conf / fluent-bit.conf to drift. Any extra arguments are passed straight
through to `helm template`, e.g.

    ./render.py --set fluentbit.accessLog.exclude.enabled=true
"""
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).parent
CHART = HERE.parent.parent / "helm"
OUT = HERE / "rendered"

# docker-compose.yml mounts these unconditionally, so they must exist even when the values
# in use don't make the chart render them.
ALWAYS_PRESENT = ("fluent-bit.conf", "fluent-bit-parsers.conf")

cmd = ["helm", "template", "lab", str(CHART), "-f", str(HERE / "lab-values.yaml")] + sys.argv[1:]
proc = subprocess.run(cmd, capture_output=True, text=True)
if proc.returncode != 0:
    print(proc.stderr, file=sys.stderr)
    sys.exit(proc.returncode)

try:
    import yaml
except ImportError:
    sys.exit("pyyaml is required: pip install pyyaml")

# helm/templates/deployment.yaml has a trailing tab after `configMap:`. Go's YAML parser
# tolerates it, PyYAML does not.
sanitized = "\n".join(line.rstrip() for line in proc.stdout.splitlines())

files = {}
for doc in yaml.safe_load_all(sanitized):
    if not doc or doc.get("kind") != "ConfigMap":
        continue
    files.update(doc.get("data") or {})

rendered = sorted(files)
for name in ALWAYS_PRESENT:
    files.setdefault(name, "# not rendered by the chart with these values\n")

OUT.mkdir(exist_ok=True)
for stale in OUT.iterdir():
    if stale.name not in files:
        stale.unlink()

# Overwrite in place rather than unlink+recreate: docker bind-mounts a single file by inode,
# so replacing the file would leave running containers reading the old contents forever.
for name, content in files.items():
    (OUT / name).write_text(content)

print("rendered:", ", ".join(rendered))
