#!/usr/bin/env bash
# Cursor `stop` hook: consume restart hints from subagentStop (error/aborted) or recover /harmonize
# when the main agent loop ends with an error while a harmonize chain is still marked active.
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

harmonize_lock_active() {
  local lock="$1/docs/plans/harmonize-run-lock.md"
  [[ -f "$lock" ]] || return 1
  grep -E '^active:' "$lock" | head -1 | awk '{print $2}' | grep -qx 'true'
}

STATUS=$(echo "$INPUT" | jq -r '.status // empty')

_hook_cwd="${CURSOR_WORKSPACE_ROOT:-$PWD}"
ROOT=$(main_repo_root "$_hook_cwd") || {
  printf '%s\n' '{}'
  exit 0
}

PENDING="$ROOT/docs/plans/.cursor-hook-restart-pending.json"

emit_supervisor_from_file() {
  local f="$1"
  local end_status="${2:-error}"
  local repo ctx msg
  repo=$(jq -r '.repo // empty' "$f")
  ctx=$(jq -r '.context // empty' "$f")
  [[ -n "$repo" ]] || repo="$ROOT"
  msg=$(
    cat <<EOF
A plan-orchestrator (supervisor) background task ended (${end_status}). Immediately dispatch a replacement background Task with run_in_background: true and subagent_type: generalPurpose. Follow agents/plan-orchestrator.md and docs/cursor-host.md in this plugin. Include repo: ${repo} and preserve mode keywords from the prior task (unblock-workflow-gh, merge-detection, dispatch-only, run, etc.). Prior context (truncated): ${ctx}
EOF
  )
  jq -n --arg m "$msg" '{followup_message: $m}'
}

emit_harmonize_from_file() {
  local f="$1"
  local end_status="${2:-stopped}"
  local repo ctx msg
  repo=$(jq -r '.repo // empty' "$f")
  ctx=$(jq -r '.context // empty' "$f")
  [[ -n "$repo" ]] || repo="$ROOT"
  msg=$(
    cat <<EOF
The default /harmonize (mode: run) background chain needs to continue (${end_status}). Dispatch a background Task (run_in_background: true, subagent_type: generalPurpose) per skills/harmonize/SKILL.md: prompt must begin with mode: run, include repo: ${repo}, and cite agents/harmonize.md plus docs/cursor-host.md. If Task is unavailable, run agents/harmonize.md inline. Prior context: ${ctx}
EOF
  )
  jq -n --arg m "$msg" '{followup_message: $m}'
}

emit_active_lock() {
  local msg
  msg=$(
    cat <<EOF
The agent loop ended with status ${STATUS} while harmonize-run-lock.md was still active. Re-run default /harmonize: dispatch a background Task (run_in_background: true, subagent_type: generalPurpose) with mode: run, repo: ${ROOT}, citing agents/harmonize.md and docs/cursor-host.md.
EOF
  )
  jq -n --arg m "$msg" '{followup_message: $m}'
}

if [[ -f "$PENDING" ]] && jq empty "$PENDING" 2>/dev/null; then
  KIND=$(jq -r '.kind // empty' "$PENDING")
  ST=$(jq -r '.status // empty' "$PENDING")
  case "$KIND" in
    plan-orchestrator)
      emit_supervisor_from_file "$PENDING" "${ST:-stopped}"
      rm -f "$PENDING"
      exit 0
      ;;
    harmonize)
      emit_harmonize_from_file "$PENDING" "${ST:-stopped}"
      rm -f "$PENDING"
      exit 0
      ;;
    *)
      rm -f "$PENDING"
      printf '%s\n' '{}'
      exit 0
      ;;
  esac
fi

if [[ "$STATUS" == error || "$STATUS" == aborted ]]; then
  if harmonize_lock_active "$ROOT"; then
    emit_active_lock
    exit 0
  fi
fi

printf '%s\n' '{}'
exit 0
