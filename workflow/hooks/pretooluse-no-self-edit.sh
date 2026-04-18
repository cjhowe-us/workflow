#!/usr/bin/env bash
# pretooluse-no-self-edit.sh
#
# Plugin files are immutable to agents. Block any Edit/Write/Bash that would
# mutate files under an installed plugin root. Changes must come via override
# scope or an external PR to the plugin repo.
set -euo pipefail

# Tool invocation context is on stdin as JSON per Claude Code hook protocol.
# Expected fields: tool_name, tool_input (varies by tool).
input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# Collect candidate write paths depending on the tool.
paths=()
case "$tool" in
  Edit|Write)
    p=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -n "$p" ] && paths+=("$p")
    ;;
  Bash)
    # Heuristic: scan the command for common write operators targeting paths.
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    # Extract tokens that look like paths used with > or >> or rm or mv or tee
    tokens=$(printf '%s' "$cmd" | grep -oE '(>>?|rm -[rf]+ |mv |tee |cp ) +[^ ]+' | awk '{print $NF}' || true)
    for t in $tokens; do paths+=("$t"); done
    ;;
esac

# Determine plugin roots to protect.
plugin_roots=()
if [ -n "${CLAUDE_PLUGIN_DIRS:-}" ]; then
  IFS=':' read -r -a dirs <<< "$CLAUDE_PLUGIN_DIRS"
  for d in "${dirs[@]}"; do
    [ -d "$d" ] || continue
    for plugin in "$d"/*; do
      [ -d "$plugin" ] && plugin_roots+=("$plugin")
    done
  done
fi

for path in "${paths[@]:-}"; do
  [ -n "$path" ] || continue
  # Resolve to absolute form for comparison (best-effort; existing files only).
  abs=$(readlink -f "$path" 2>/dev/null || printf '%s' "$path")
  for root in "${plugin_roots[@]:-}"; do
    root_abs=$(readlink -f "$root" 2>/dev/null || printf '%s' "$root")
    case "$abs" in
      "$root_abs"/*)
        printf 'workflow: write denied under plugin root %s\n' "$root_abs" >&2
        printf '  Plugin files are immutable to agents. Use override scope or open a PR to the plugin repo.\n' >&2
        exit 2
        ;;
    esac
  done
done

exit 0
