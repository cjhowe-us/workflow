#!/usr/bin/env bash
# workflow-conformance.sh
#
# Validate a workflow (or artifact-template) file against the
# workflow-contract schema. Exits 0 on pass, non-zero on violation with
# line-level errors on stderr.
#
# Usage:
#   workflow-conformance.sh <path-to-SKILL.md>
set -euo pipefail

path="${1:?path to SKILL.md required}"
[ -f "$path" ] || { echo "not-found: $path" >&2; exit 2; }

fail=0
warn() { echo "workflow-conformance: $*" >&2; fail=1; }

# Extract YAML frontmatter.
fm=$(awk '
  BEGIN { in_fm=0 }
  /^---[[:space:]]*$/ {
    if (in_fm == 0) { in_fm=1; next } else { exit }
  }
  in_fm==1 { print }
' "$path")

[ -n "$fm" ] || { warn "missing YAML frontmatter"; exit 1; }

# Parse with python+yaml for robust validation.
python3 - "$path" <<'PY' || fail=1
import sys, yaml, re, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text()

m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
if not m:
    print(f"workflow-conformance: bad frontmatter delimiter in {path}", file=sys.stderr)
    sys.exit(1)

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    print(f"workflow-conformance: invalid YAML: {e}", file=sys.stderr)
    sys.exit(1)

errors = []

def req(key, where="root"):
    if key not in fm:
        errors.append(f"{where}: missing required key `{key}`")

for k in ("name", "description"):
    req(k)

if "contract_version" not in fm:
    errors.append("root: missing `contract_version` (set to 1)")

graph = fm.get("graph") or {}
if "steps" not in graph:
    errors.append("graph: missing `steps`")
else:
    steps = graph["steps"]
    if not isinstance(steps, list) or not steps:
        errors.append("graph.steps: must be a non-empty list")
    else:
        ids = []
        for i, s in enumerate(steps):
            if not isinstance(s, dict):
                errors.append(f"graph.steps[{i}]: must be a mapping")
                continue
            if "id" not in s:
                errors.append(f"graph.steps[{i}]: missing `id`")
                continue
            if s["id"] in ids:
                errors.append(f"graph.steps[{i}]: duplicate id `{s['id']}`")
            ids.append(s["id"])

        trs = graph.get("transitions") or []
        for j, t in enumerate(trs):
            if not isinstance(t, dict):
                errors.append(f"graph.transitions[{j}]: must be a mapping")
                continue
            for k in ("id", "from", "to"):
                if k not in t:
                    errors.append(f"graph.transitions[{j}]: missing `{k}`")
            if t.get("from") and t["from"] not in ids:
                errors.append(f"graph.transitions[{j}]: from `{t['from']}` not in steps")
            if t.get("to") and t["to"] not in ids:
                errors.append(f"graph.transitions[{j}]: to `{t['to']}` not in steps")

        db = fm.get("dynamic_branches") or []
        tids = [t.get("id") for t in trs]
        for k, b in enumerate(db):
            if b.get("step") not in ids:
                errors.append(f"dynamic_branches[{k}]: step `{b.get('step')}` not in steps")
            for tid in (b.get("transitions") or []):
                if tid not in tids:
                    errors.append(f"dynamic_branches[{k}]: transition `{tid}` not in transitions")

for e in errors:
    print(f"workflow-conformance: {e}", file=sys.stderr)

sys.exit(1 if errors else 0)
PY

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "workflow-conformance: $path OK"
exit 0
