#!/usr/bin/env bash
# sessionstart-env-check.sh
#
# Gate: verify prerequisites for the workflow plugin.
#   - gh CLI installed + authenticated (workflow artifacts live on GitHub)
#   - git available
#   - CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 (teammate dispatch is required)
#
# Non-fatal: prints warnings for missing optional pieces; only fails hard
# when the environment cannot support basic workflow operation.
set -euo pipefail

warn() { printf 'workflow: %s\n' "$*" >&2; }

fail=0

if ! command -v git >/dev/null 2>&1; then
  warn "git not found on PATH. Install git to use the workflow plugin."
  fail=1
fi

if ! command -v gh >/dev/null 2>&1; then
  warn "gh CLI not found. Install GitHub CLI: https://cli.github.com/"
  warn "  (required for GitHub-backed artifact providers)"
fi

if command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    warn "gh is not authenticated. Run: gh auth login"
    warn "  identity comes from 'gh auth status' — no login dialog."
  fi
fi

if [ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" != "1" ]; then
  warn "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS must be set to 1."
  warn "  Use env-setup plugin or export it in your shell rc."
  exit 2
fi

if [ "$fail" -ne 0 ]; then
  exit 2
fi

exit 0
