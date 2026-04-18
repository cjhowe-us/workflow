#!/usr/bin/env bash
# posttooluse-progress.sh
#
# Auto-append a progress entry to the current execution's provider after every
# Edit/Write/Bash tool call that produced visible effect. Keeps the step
# ledger honest without requiring workers to manually emit progress events.
#
# Reads the active execution URI from $XDG_STATE_HOME/workflow/dispatch.json
# (written by the default orchestrator). If no active execution, exits 0.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
dispatch="$XDG_STATE_HOME/workflow/dispatch.json"

[ -f "$dispatch" ] || exit 0

exec_uri=$(jq -r '.current_execution // empty' "$dispatch" 2>/dev/null)
[ -n "$exec_uri" ] || exit 0

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
summary=""
case "$tool" in
  Edit|Write)
    path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
    summary="$tool $path"
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' | head -c 120)
    summary="Bash: $cmd"
    ;;
  *)
    summary="$tool"
    ;;
esac

[ -n "$summary" ] || exit 0

# Build progress entry. Provider + kind derived from URI scheme
# ("execution:<id>" → kind=execution).
kind="${exec_uri%%:*}"
entry=$(jq -n --arg s "$summary" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg tool "$tool" \
  '{at:$at, kind:"tool_use", summary:$s, tool:$tool, auto_generated:true}')

plugin_root="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(realpath "$0")")")}"
"$plugin_root/scripts/run-provider.sh" "$kind" "" progress --uri "$exec_uri" --append - <<< "$entry" || true

exit 0
