#!/usr/bin/env bash
# orchestrator-lock.sh
#
# Operate on the per-machine orchestrator flock.
#
# Usage:
#   orchestrator-lock.sh status   → print current holder (or "free")
#   orchestrator-lock.sh release  → clear the lock file (use with caution)
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
lock_file="$XDG_STATE_HOME/workflow/orchestrator.lock"

case "${1:?status|release}" in
  status)
    if [ ! -f "$lock_file" ]; then
      echo "free"
      exit 0
    fi
    pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      jq -c . "$lock_file"
    else
      echo "free (stale)"
    fi
    ;;
  release)
    rm -f "$lock_file"
    echo "released"
    ;;
  *)
    echo "unknown subcommand: $1" >&2
    exit 2
    ;;
esac
