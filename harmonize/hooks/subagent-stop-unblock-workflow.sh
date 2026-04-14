#!/usr/bin/env bash
# SubagentStop: always record unblock hook run; emit followup_message only when no duplicate work.
# Skips when harmonize run lock is active or in-flight already has plan-orchestrator unblock/merge pass.
set -euo pipefail

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{}'
  exit 0
fi

main_repo_root() {
  local d="$1"
  [[ -n "$d" ]] || return 1
  d=$(cd "$d" && pwd) || return 1
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || return 1
  local g
  g=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
    || g=$(git -C "$d" rev-parse --git-common-dir 2>/dev/null) || return 1
  if [[ "$g" != /* ]]; then
    local top
    top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || return 1
    g="$top/$g"
  fi
  dirname "$g"
}

_hook_cwd=$(echo "$INPUT" | jq -r '.cwd // empty')
if [[ -z "$_hook_cwd" ]]; then
  _hook_cwd="${CURSOR_WORKSPACE_ROOT:-${CLAUDE_PROJECT_ROOT:-$PWD}}"
fi

ROOT=$(main_repo_root "$_hook_cwd") || {
  printf '%s\n' '{}'
  exit 0
}

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "SubagentStop"')
if [[ "$HOOK_EVENT" == "WorktreeRemove" ]]; then
  printf '%s\n' '{}'
  exit 0
fi

mkdir -p "$ROOT/docs/plans"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PENDING="$ROOT/docs/plans/.cursor-hook-unblock-pending.json"

tmp="${PENDING}.tmp.$$"
if [[ -f "$PENDING" ]] && jq empty "$PENDING" 2>/dev/null; then
  jq --arg now "$NOW" --arg reason subagent_stop --arg repo "$ROOT" \
    '. + {requested_at: $now, last_unblock_hook_at: $now, reason: $reason, repo: $repo}' \
    "$PENDING" >"$tmp"
else
  jq -n --arg now "$NOW" --arg reason subagent_stop --arg repo "$ROOT" \
    '{requested_at: $now, last_unblock_hook_at: $now, reason: $reason, repo: $repo}' >"$tmp"
fi
mv "$tmp" "$PENDING" || rm -f "$tmp"

LOCK="$ROOT/docs/plans/harmonize-run-lock.md"
IN_FLIGHT="$ROOT/docs/plans/in-flight.md"

lock_active_true() {
  [[ -f "$LOCK" ]] || return 1
  grep -E '^active:' "$LOCK" | head -1 | awk '{print $2}' | grep -qx 'true'
}

in_flight_has_plan_orchestrator_unblock() {
  [[ -f "$IN_FLIGHT" ]] || return 1
  grep -qi 'plan-orchestrator' "$IN_FLIGHT" || return 1
  grep -qiE 'unblock-workflow|merge-detection' "$IN_FLIGHT"
}

if lock_active_true; then
  printf '%s\n' '{}'
  exit 0
fi

if in_flight_has_plan_orchestrator_unblock; then
  printf '%s\n' '{}'
  exit 0
fi

msg=$(
  cat <<EOF
Harmonize unblock workflow (SubagentStop): run a background Task (run_in_background: true, subagent_type: generalPurpose) with prompt starting mode: unblock-workflow, include repo: ${ROOT}, and cite agents/harmonize.md plus docs/cursor-host.md. If Task is unavailable, run agents/harmonize.md inline for the same mode. This pass runs the full unblock chain (gh on PLAN-* PRs, then post-merge dispatch for reviews and ready work). Skip dispatch if docs/plans/in-flight.md already shows an active plan-orchestrator unblock pass.
EOF
)

jq -n --arg m "$msg" '{followup_message: $m}'
