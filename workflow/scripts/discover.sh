#!/usr/bin/env bash
# discover.sh
#
# Rebuild the registry of installed workflows, templates, and providers. Thin
# wrapper over the SessionStart discovery hook: call this during a session to
# pick up a newly-installed plugin or a scope-level override without
# reopening Claude Code.
set -euo pipefail
plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
exec "$plugin_root/hooks/sessionstart-discover.sh"
