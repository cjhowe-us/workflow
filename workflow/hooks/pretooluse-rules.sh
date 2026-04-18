#!/usr/bin/env bash
# pretooluse-rules.sh
#
# Opt-in workflow rule enforcement. If the current workflow declares a `rules`
# block in its frontmatter (loaded via the execution provider), this hook
# checks the imminent tool call against tools_allowed, tools_denied, and
# write_paths_denied lists. Absent rules = pass through unrestricted.
#
# Stub implementation: the enforcement path reads the current execution's
# workflow URI from the session's dispatch ledger ($XDG_STATE_HOME/workflow/
# dispatch.json) and queries the provider for the workflow definition. When
# the ledger doesn't name a workflow, it exits 0 without restriction.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
dispatch="$XDG_STATE_HOME/workflow/dispatch.json"

# If no active workflow, don't restrict.
[ -f "$dispatch" ] || exit 0

# Pass through for now; real enforcement lands with the dispatch-engine workflow.
exit 0
