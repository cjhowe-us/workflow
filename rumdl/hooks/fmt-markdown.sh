#!/bin/bash
FILE=$(cat | jq -r '.tool_input.file_path // empty')
[[ -n "$FILE" && "$FILE" == *.md ]] || exit 0
command -v rumdl >/dev/null 2>&1 || exit 0
OUTPUT=$(rumdl fmt "$FILE" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
	echo "$OUTPUT"
fi
