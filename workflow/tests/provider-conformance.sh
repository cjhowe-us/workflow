#!/usr/bin/env bash
# provider-conformance.sh
#
# Validate an artifact provider against the artifact-contract surface.
# Checks:
#   - SKILL.md frontmatter has contract_version, name, description
#   - scripts/artifact.sh exists + executable
#   - artifact.sh responds to `--help` / unknown subcommand with non-zero
#     exit and a JSON `{"error":"..."}` payload
#   - subcommand list covers get|create|update|list|lock|release|status|progress
#
# Usage:
#   provider-conformance.sh <path-to-provider-dir>
set -euo pipefail

dir="${1:?provider directory required}"
[ -d "$dir" ] || { echo "not-found: $dir" >&2; exit 2; }

fail=0
warn() { echo "provider-conformance: $*" >&2; fail=1; }

manifest="$dir/manifest.json"
[ -f "$manifest" ] || { warn "missing manifest.json"; exit 1; }

# manifest.json must carry name + description + contract_version.
python3 - "$manifest" <<'PY' || fail=1
import sys, json, pathlib
p = pathlib.Path(sys.argv[1])
try:
    m = json.loads(p.read_text())
except json.JSONDecodeError as e:
    print(f"provider-conformance: invalid JSON: {e}", file=sys.stderr)
    sys.exit(1)
missing = [k for k in ("name","description","contract_version") if k not in m]
if missing:
    print(f"provider-conformance: missing keys: {missing}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY

script="$dir/artifact.sh"
[ -x "$script" ] || warn "artifact.sh not found or not executable"

if [ -x "$script" ]; then
  # Unknown subcommand → non-zero + JSON error
  if ! out=$("$script" __definitely_not_a_subcommand__ 2>/dev/null); then
    if ! jq -e '.error' >/dev/null 2>&1 <<< "$out"; then
      warn "unknown-subcommand did not return {\"error\":...}"
    fi
  else
    warn "unknown-subcommand exited 0 (expected non-zero)"
  fi

  # Each required subcommand must exist as a `case` arm. Combined arms
  # like `lock|release)` are legal. Match either a leading occurrence
  # (start-of-line or space, followed by name, then `)` or `|`) or an
  # occurrence after a pipe.
  for sub in get create update list lock release status progress; do
    if ! grep -qE "(^|[[:space:]|])${sub}(\)|\|)" "$script"; then
      warn "subcommand not found in artifact.sh: $sub"
    fi
  done
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "provider-conformance: $dir OK"
exit 0
