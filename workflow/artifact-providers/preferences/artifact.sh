#!/usr/bin/env bash
# preferences provider — artifact.sh
# URIs: preferences:workspace | preferences:user
set -euo pipefail

die() { printf '{"error":"%s"}\n' "$*"; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found"; }
need jq

path_for() {
  case "${1#preferences:}" in
    workspace) printf '%s\n' "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude/workflow.preferences.json" ;;
    user)      printf '%s\n' "$HOME/.claude/workflow.preferences.json" ;;
    *)         die "bad preferences uri: $1" ;;
  esac
}

read_or_empty() { [ -f "$1" ] && cat "$1" || echo '{}'; }

cmd="${1:?subcommand required}"; shift || true

case "$cmd" in
  get)
    uri=""; while [ $# -gt 0 ]; do case "$1" in --uri) uri="$2"; shift 2;; *) shift;; esac; done
    f=$(path_for "$uri")
    jq --arg uri "$uri" '. + {uri:$uri}' <<< "$(read_or_empty "$f")"
    ;;
  create|update)
    uri=""; data_path=""; patch_path=""
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --data) data_path="$2"; shift 2;;
      --patch) patch_path="$2"; shift 2;;
      *) shift;; esac; done
    [ -n "$uri" ] || die "--uri required"
    src_path="${patch_path:-$data_path}"
    incoming=$( [ "$src_path" = "-" ] && cat || cat "$src_path" )
    f=$(path_for "$uri")
    mkdir -p "$(dirname "$f")"
    current=$(read_or_empty "$f")
    merged=$(jq -c -s '.[0] * .[1]' <(echo "$current") <(echo "$incoming"))
    printf '%s\n' "$merged" > "$f"
    jq -n --arg uri "$uri" '{uri:$uri, updated:true}'
    ;;
  list)
    jq -n '{entries:[{uri:"preferences:workspace"},{uri:"preferences:user"}]}'
    ;;
  lock|release)
    jq -n '{held:true, current_owner:"local"}'
    ;;
  status)
    uri=""; while [ $# -gt 0 ]; do case "$1" in --uri) uri="$2"; shift 2;; *) shift;; esac; done
    jq -n --arg uri "$uri" '{uri:$uri, status:"complete"}'
    ;;
  progress)
    jq -n '{entries:[]}'
    ;;
  *)
    die "unknown subcommand: $cmd"
    ;;
esac
