#!/usr/bin/env bash
# sessionstart-orchestrator-lock.sh
#
# Per-machine flock: at most one /workflow orchestrator per machine. Multiple
# machines for the same GH user are allowed (tracked in the presence gist).
#
# Writes $XDG_STATE_HOME/workflow/orchestrator.lock with the current session's
# {pid, session_id, started_at}. If a fresh (pid-alive) lock exists from a
# different session, exits non-zero and prints the holder's info.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
state_dir="$XDG_STATE_HOME/workflow"
mkdir -p "$state_dir"
lock_file="$state_dir/orchestrator.lock"

session_id="${CLAUDE_SESSION_ID:-sess-$(date +%s)-$$}"
pid=$$
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# If a lock exists, check whether its PID is alive.
if [ -f "$lock_file" ]; then
  existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null || true)
  existing_session=$(jq -r '.session_id // empty' "$lock_file" 2>/dev/null || true)
  if [ -n "$existing_pid" ] && [ "$existing_pid" != "$pid" ]; then
    if kill -0 "$existing_pid" 2>/dev/null; then
      if [ "$existing_session" != "$session_id" ]; then
        printf 'workflow: another orchestrator is running on this machine (pid %s, session %s).\n' \
          "$existing_pid" "$existing_session" >&2
        printf 'Exit that session first, or wait for it to terminate.\n' >&2
        exit 2
      fi
    fi
  fi
fi

jq -n --arg pid "$pid" --arg sid "$session_id" --arg at "$started_at" \
  '{pid:($pid|tonumber), session_id:$sid, started_at:$at}' > "$lock_file"

exit 0
