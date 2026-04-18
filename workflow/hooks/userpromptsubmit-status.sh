#!/usr/bin/env bash
# userpromptsubmit-status.sh
#
# Inject a compact dashboard summary before each user turn. Reads:
#   - orchestrator lock ($XDG_STATE_HOME/workflow/orchestrator.lock)
#   - registry ($XDG_STATE_HOME/workflow/registry.json) for workflow counts
#
# Emits a short multi-line summary to stdout; Claude Code renders it in the
# status line / pre-turn context. Kept minimal to avoid token bloat.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
state_dir="$XDG_STATE_HOME/workflow"
lock_file="$state_dir/orchestrator.lock"
registry="$state_dir/registry.json"

gh_user=$(gh api user --jq .login 2>/dev/null || echo unknown)

line=""
if [ -f "$lock_file" ]; then
  sid=$(jq -r '.session_id // "?"' "$lock_file" 2>/dev/null)
  line+="[workflow] session=$sid user=$gh_user"
else
  line+="[workflow] no active session"
fi

if [ -f "$registry" ]; then
  wf=$(jq '.entries | map(select(.kind=="workflow")) | length' "$registry" 2>/dev/null || echo 0)
  tpl=$(jq '.entries | map(select(.kind=="artifact-template")) | length' "$registry" 2>/dev/null || echo 0)
  prov=$(jq '.entries | map(select(.kind=="artifact-provider")) | length' "$registry" 2>/dev/null || echo 0)
  line+=" · $wf workflows, $tpl templates, $prov providers"
fi

echo "$line"
exit 0
