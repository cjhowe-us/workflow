#!/usr/bin/env bash
# SessionStart: hard-block if agent teams is not enabled (coordinator plugin
# cannot function without it). Warn about other missing config (gh auth,
# project settings) but do not block those.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

# Agent teams experimental flag — REQUIRED. Block session if missing.
if [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" != "1" ]]; then
  plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
  echo "coordinator plugin: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not set to 1." >&2
  echo "The orchestrator cannot dispatch workers without agent teams." >&2
  echo "" >&2
  echo "Run one of these to persist it for your shell, then restart your terminal:" >&2
  echo "  bash/zsh/fish:  $plugin_root/scripts/ensure-agent-teams-env.sh" >&2
  echo "  PowerShell:     pwsh -NoProfile -File $plugin_root/scripts/ensure-agent-teams-env.ps1" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{}'
  exit 0
fi

warnings=()

# gh CLI present and authenticated
if ! command -v gh >/dev/null 2>&1; then
  warnings+=("gh CLI is not installed — coordinator needs it for GitHub Project v2 mutations.")
elif ! gh auth status >/dev/null 2>&1; then
  warnings+=("gh CLI is not authenticated — run 'gh auth login' with read:project, project, repo scopes.")
fi

# Project config file
cwd=$(echo "$INPUT" | jq -r '.cwd // empty')
[[ -z "$cwd" ]] && cwd="${PWD}"
cfg="$cwd/.claude/coordinator.local.md"
if [[ ! -f "$cfg" ]]; then
  warnings+=("No .claude/coordinator.local.md found at $cwd — orchestrator will prompt for project_id on first /coordinator invocation.")
fi

if (( ${#warnings[@]} == 0 )); then
  printf '%s\n' '{}'
  exit 0
fi

msg="coordinator plugin warnings:\n"
for w in "${warnings[@]}"; do
  msg+="  - ${w}\n"
done

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $msg
  }
}'
