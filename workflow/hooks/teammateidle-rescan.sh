#!/usr/bin/env bash
# teammateidle-rescan.sh
#
# On teammate-idle, nudge the orchestrator to re-poll providers for
# execution status and retroactive-step drift. Writes a rescan flag the
# default orchestrator consumes on its next turn.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
state_dir="$XDG_STATE_HOME/workflow"
mkdir -p "$state_dir"
flag="$state_dir/rescan.flag"

date -u +%Y-%m-%dT%H:%M:%SZ > "$flag"

exit 0
