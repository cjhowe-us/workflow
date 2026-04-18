#!/usr/bin/env bash
# run-provider.sh
#
# Dispatch to an artifact provider's artifact.sh script.
#
# Usage:
#   run-provider.sh <kind> <impl> <subcommand> [args...]
#
# If <impl> is empty, the active implementation is resolved via
# $XDG_STATE_HOME/workflow/registry.json + workspace/user preferences.
#
# Contract (artifact.sh subcommands):
#   get --uri U
#   create --data F
#   update --uri U --patch F
#   list --filter F
#   lock --uri U --owner O
#   lock --uri U --check --owner O
#   release --uri U --owner O
#   status --uri U
#   progress --uri U
#   progress --uri U --append F   (or via stdin when F is -)
set -euo pipefail

kind="${1:?kind required (items|changes|docs|execution|...)}"
impl="${2:-}"
subcommand="${3:?subcommand required}"
shift 3 || true

: "${XDG_STATE_HOME:=$HOME/.local/state}"
registry="$XDG_STATE_HOME/workflow/registry.json"

resolve_provider_path() {
  local kind="$1" impl="$2"
  if [ -z "$impl" ]; then
    # Default impl lookup: first provider of this kind in the registry.
    impl=$(jq -r --arg k "$kind" '
      .entries
      | map(select(.kind == "artifact-provider"))
      | map(select(.name == $k or (.name | startswith($k + "-"))))
      | .[0].name // empty
    ' "$registry" 2>/dev/null)
  fi
  [ -n "$impl" ] || return 1

  jq -r --arg name "$impl" '
    .entries
    | map(select(.kind == "artifact-provider" and .name == $name))
    | .[0].path // empty
  ' "$registry" 2>/dev/null
}

manifest=$(resolve_provider_path "$kind" "$impl")
if [ -z "$manifest" ]; then
  printf 'run-provider: no artifact provider found for kind=%s impl=%s\n' "$kind" "$impl" >&2
  exit 2
fi

# Registry entry's `path` points at manifest.json; artifact.sh lives alongside.
provider_dir=$(dirname "$manifest")
script="$provider_dir/artifact.sh"

if [ ! -x "$script" ]; then
  printf 'run-provider: %s not executable\n' "$script" >&2
  exit 2
fi

exec "$script" "$subcommand" "$@"
