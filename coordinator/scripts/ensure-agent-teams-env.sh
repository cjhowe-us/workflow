#!/usr/bin/env bash
# Ensure CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is persisted in the user's
# shell config. Idempotent: appends only if the var is not already set in
# the target file. Shell detection is delegated to detect-shell.sh so every
# supported shell (zsh, bash, fish, POSIX) uses the right file + syntax.
#
# Usage:
#   ensure-agent-teams-env.sh           # detect and patch
#   ensure-agent-teams-env.sh --dry-run # detect and print what would happen
#
# For native Windows PowerShell, use ensure-agent-teams-env.ps1 instead.
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

VAR="CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
VALUE="1"

here="$(cd "$(dirname "$0")" && pwd)"
det=$("$here/detect-shell.sh" --var "$VAR" --value "$VALUE")

# Tiny JSON field extractor (values are single-line simple strings in our schema).
json_get() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\\([^\"]*\\)\".*/\\1/p"; }

shell=$(json_get "$det" shell)
cfg=$(json_get   "$det" config_file)
line=$(json_get  "$det" line)

if [[ -f "$cfg" ]] && grep -q -- "$VAR" "$cfg"; then
  echo "already set in $cfg (shell: $shell). No change."
  exit 0
fi

if (( DRY_RUN )); then
  echo "would append to $cfg (shell: $shell):"
  echo "    $line"
  exit 0
fi

mkdir -p "$(dirname "$cfg")"
touch "$cfg"

# Leading blank line for separation, trailing newline for cleanliness.
printf '\n# Enable Claude Code agent teams (required by the coordinator plugin)\n%s\n' \
  "$line" >> "$cfg"

echo "appended $VAR=$VALUE to $cfg (shell: $shell)."
echo "Open a new shell session (or run 'source $cfg') to pick it up."
