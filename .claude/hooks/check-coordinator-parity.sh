#!/usr/bin/env bash
# PostToolUse hook: when Claude edits a .sh or .ps1 under coordinator/,
# enforce that the sibling file (same basename, swapped extension) exists.
# Optionally run the PowerShell parity test if `pwsh` is available.
#
# Emits a `decision: block` with feedback when out of parity so Claude fixes
# the companion file in the same turn.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{}'
  exit 0
fi

# Extract the file path from the tool input (Write / Edit / MultiEdit payloads
# all carry `tool_input.file_path`).
file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ -z "$file_path" ]]; then
  printf '%s\n' '{}'
  exit 0
fi

# Only interested in coordinator/hooks/** and coordinator/scripts/**.
if [[ "$file_path" != *"/coordinator/hooks/"* && "$file_path" != *"/coordinator/scripts/"* ]]; then
  printf '%s\n' '{}'
  exit 0
fi

# Only .sh or .ps1.
ext="${file_path##*.}"
if [[ "$ext" != "sh" && "$ext" != "ps1" ]]; then
  printf '%s\n' '{}'
  exit 0
fi

if [[ "$ext" == "sh" ]]; then
  sibling="${file_path%.sh}.ps1"
  sibling_kind="PowerShell"
else
  sibling="${file_path%.ps1}.sh"
  sibling_kind="bash"
fi

problems=()
if [[ ! -f "$sibling" ]]; then
  problems+=("Missing $sibling_kind companion: $sibling — parity requires a sibling script with the same behavior.")
fi

# Optional: run pwsh parity test if available (catches missing files and
# PowerShell parse errors across the whole plugin).
pwsh_output=""
pwsh_exit=0
if command -v pwsh >/dev/null 2>&1; then
  # Find the coordinator root from the edited file path.
  coord_root="${file_path%/coordinator/*}/coordinator"
  parity_test="$coord_root/tests/test-parity.ps1"
  if [[ -f "$parity_test" ]]; then
    set +e
    pwsh_output=$(pwsh -NoProfile -File "$parity_test" 2>&1)
    pwsh_exit=$?
    set -e
    if (( pwsh_exit != 0 )); then
      problems+=("pwsh parity test failed:")
      problems+=("$pwsh_output")
    fi
  fi
fi

if (( ${#problems[@]} == 0 )); then
  printf '%s\n' '{}'
  exit 0
fi

msg="coordinator plugin: shell-script parity violation detected after editing $file_path\n\n"
for p in "${problems[@]}"; do
  msg+="$p"$'\n'
done
msg+=$'\nRequired: keep bash (.sh) and PowerShell (.ps1) companions in sync so the plugin works on macOS, Linux, and Windows. After editing one, update the other to match in behavior.'

jq -n --arg reason "$msg" '{
  decision: "block",
  reason: $reason
}'
