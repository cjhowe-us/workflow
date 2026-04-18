#!/usr/bin/env bash
# subagentstop-release.sh
#
# On subagent (teammate) stop, release any worktree ownership this worker
# held in the orchestrator's in-session dispatch ledger. Does NOT release
# artifact-level locks (those transfer via manual user action — e.g. GitHub
# assignee change); only clears the machine-local dispatch state so the
# worktree is available for the next worker.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
dispatch="$XDG_STATE_HOME/workflow/dispatch.json"

[ -f "$dispatch" ] || exit 0

input=$(cat)
teammate=$(printf '%s' "$input" | jq -r '.teammate_id // .agent_id // empty')
[ -n "$teammate" ] || exit 0

tmp="$(mktemp)"
jq --arg id "$teammate" '
  .workers //= {}
  | .worktrees //= {}
  | .workers[$id] = null
  | .worktrees = (.worktrees | with_entries(select(.value.worker_id != $id)))
' "$dispatch" > "$tmp" && mv "$tmp" "$dispatch"

exit 0
