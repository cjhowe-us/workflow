#!/usr/bin/env bash
# SubagentStop / TaskCompleted: clear Project v2 lock_owner + lock_expires_at for any items
# whose lock_owner matches the stopped worker's id. Idempotent — safe to run when no lock held.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

if ! command -v jq >/dev/null 2>&1 || ! command -v gh >/dev/null 2>&1; then
  printf '%s\n' '{}'
  exit 0
fi

agent_id=$(echo "$INPUT" | jq -r '.agent_id // .subagent_id // .task_id // empty')
[[ -z "$agent_id" ]] && { printf '%s\n' '{}'; exit 0; }

# Skip if not a coordinator worker (match subagent_type)
subagent_type=$(echo "$INPUT" | jq -r '.subagent_type // .agent_type // empty')
if [[ -n "$subagent_type" && "$subagent_type" != "coordinator-worker" ]]; then
  printf '%s\n' '{}'
  exit 0
fi

cwd=$(echo "$INPUT" | jq -r '.cwd // empty')
[[ -z "$cwd" ]] && cwd="${PWD}"
cfg="$cwd/.claude/coordinator.local.md"
[[ -f "$cfg" ]] || { printf '%s\n' '{}'; exit 0; }

project_id=$(awk -F': *' '/^project_id:/ { print $2; exit }' "$cfg" | tr -d '"' | tr -d "'")
[[ -z "$project_id" ]] && { printf '%s\n' '{}'; exit 0; }

# Find and clear matching items (best-effort; on error, emit empty JSON)
if ! "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/lock-release.sh" \
    --project "$project_id" --owner-matches "$agent_id" 2>/dev/null; then
  :
fi

printf '%s\n' '{}'
