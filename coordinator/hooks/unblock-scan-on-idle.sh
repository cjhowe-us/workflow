#!/usr/bin/env bash
# SubagentStop / TaskCompleted / TeammateIdle: tell the orchestrator to rescan for newly
# dispatchable items. Debounced (default 30s) to avoid thrash under rapid event bursts.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{}'
  exit 0
fi

DEBOUNCE_SEC="${COORDINATOR_UNBLOCK_HOOK_DEBOUNCE_SEC:-30}"

cwd=$(echo "$INPUT" | jq -r '.cwd // empty')
[[ -z "$cwd" ]] && cwd="${PWD}"

# Debounce file lives outside the repo (we do not write to repo from coordinator).
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/coordinator"
mkdir -p "$state_dir"
pending="$state_dir/unblock-pending.json"

now_epoch=$(date -u +%s)
prev_epoch=0
if [[ -f "$pending" ]] && jq empty "$pending" 2>/dev/null; then
  prev_epoch=$(jq -r '.last_emit_epoch // 0' "$pending" 2>/dev/null || echo 0)
fi
[[ "$prev_epoch" =~ ^[0-9]+$ ]] || prev_epoch=0

if (( now_epoch - prev_epoch < DEBOUNCE_SEC )); then
  printf '%s\n' '{}'
  exit 0
fi

jq -n --argjson now "$now_epoch" '{ last_emit_epoch: $now }' > "$pending"

jq -n '{
  hookSpecificOutput: {
    additionalContext: "coordinator: rescan the project for newly dispatchable items and fill any free worker slots."
  }
}'
