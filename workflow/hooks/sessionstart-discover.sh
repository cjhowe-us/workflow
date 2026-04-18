#!/usr/bin/env bash
# sessionstart-discover.sh
#
# Build a lazy-loaded registry of installed workflows, artifact templates, and
# artifact providers from every installed plugin plus workspace / user /
# override scopes. Reads only SKILL.md frontmatter — never loads bodies. Output
# is a single JSON file at $XDG_STATE_HOME/workflow/registry.json consumed by
# the `default` orchestrator on demand.
set -euo pipefail

: "${XDG_STATE_HOME:=$HOME/.local/state}"
state_dir="$XDG_STATE_HOME/workflow"
mkdir -p "$state_dir"
registry="$state_dir/registry.json"
tmp="$(mktemp)"

# Collect scope roots in precedence order.
#   override  → $CWD/.workflow-override
#   workspace → <repo-root>/.claude
#   user      → $HOME/.claude
#   plugin    → every installed plugin root on CLAUDE_PLUGIN_DIRS
scopes_json='[]'
cwd="$(pwd)"
if [ -d "$cwd/.workflow-override" ]; then
  scopes_json=$(printf '%s' "$scopes_json" | jq --arg p "$cwd/.workflow-override" --arg s override \
    '. + [{scope:$s, root:$p}]')
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ] && [ -d "$repo_root/.claude" ]; then
  scopes_json=$(printf '%s' "$scopes_json" | jq --arg p "$repo_root/.claude" --arg s workspace \
    '. + [{scope:$s, root:$p}]')
fi

if [ -d "$HOME/.claude" ]; then
  scopes_json=$(printf '%s' "$scopes_json" | jq --arg p "$HOME/.claude" --arg s user \
    '. + [{scope:$s, root:$p}]')
fi

# Plugin roots: CLAUDE_PLUGIN_DIRS is colon-separated
if [ -n "${CLAUDE_PLUGIN_DIRS:-}" ]; then
  IFS=':' read -r -a dirs <<< "$CLAUDE_PLUGIN_DIRS"
  for d in "${dirs[@]}"; do
    if [ -d "$d" ]; then
      # Each immediate child is a plugin
      for plugin in "$d"/*; do
        [ -d "$plugin/skills" ] && scopes_json=$(printf '%s' "$scopes_json" \
          | jq --arg p "$plugin" --arg s plugin '. + [{scope:$s, root:$p}]')
      done
    fi
  done
fi

# Walk each scope's skills/{workflows, artifact-templates, artifact-providers}
# and extract frontmatter name + description via a minimal YAML parser.
extract_frontmatter() {
  # stdin: a SKILL.md body; stdout: JSON {name, description, contract_version?}
  awk '
    BEGIN { in_fm=0; out=""; }
    /^---[[:space:]]*$/ {
      if (in_fm == 0) { in_fm=1; next } else { exit }
    }
    in_fm==1 {
      print $0
    }
  ' | python3 -c 'import sys,yaml,json; d=yaml.safe_load(sys.stdin.read()) or {}; print(json.dumps({"name":d.get("name"),"description":d.get("description"),"contract_version":d.get("contract_version")}))' 2>/dev/null || echo '{}'
}

entries='[]'
echo "$scopes_json" | jq -c '.[]' | while read -r scope_entry; do
  scope=$(echo "$scope_entry" | jq -r .scope)
  root=$(echo "$scope_entry" | jq -r .root)
  # workflows
  for path in "$root"/skills/workflows/*/SKILL.md \
              "$root"/workflows/*/SKILL.md; do
    [ -f "$path" ] || continue
    fm=$(extract_frontmatter < "$path")
    name=$(echo "$fm" | jq -r '.name // empty')
    [ -n "$name" ] && entries=$(printf '%s' "$entries" | jq --arg scope "$scope" --arg path "$path" --arg kind workflow --argjson fm "$fm" \
      '. + [{kind:$kind, scope:$scope, path:$path, name:$fm.name, description:$fm.description}]')
  done
  # artifact-templates
  for path in "$root"/skills/artifact-templates/*/SKILL.md \
              "$root"/skills/artifact-templates/*/TEMPLATE.md \
              "$root"/artifact-templates/*/SKILL.md; do
    [ -f "$path" ] || continue
    fm=$(extract_frontmatter < "$path")
    name=$(echo "$fm" | jq -r '.name // empty')
    [ -n "$name" ] && entries=$(printf '%s' "$entries" | jq --arg scope "$scope" --arg path "$path" --arg kind artifact-template --argjson fm "$fm" \
      '. + [{kind:$kind, scope:$scope, path:$path, name:$fm.name, description:$fm.description}]')
  done
  # artifact-providers (not skills — plain directories with a manifest.json)
  for path in "$root"/artifact-providers/*/manifest.json; do
    [ -f "$path" ] || continue
    # manifest.json is already valid JSON; no frontmatter extraction needed.
    fm=$(cat "$path")
    name=$(echo "$fm" | jq -r '.name // empty')
    [ -n "$name" ] && entries=$(printf '%s' "$entries" | jq --arg scope "$scope" --arg path "$path" --arg kind artifact-provider --argjson fm "$fm" \
      '. + [{kind:$kind, scope:$scope, path:$path, name:$fm.name, description:$fm.description, contract_version:$fm.contract_version}]')
  done
  echo "$entries" > "$tmp"
done

# Subshell above wipes state; re-emit from $tmp.
entries="$(cat "$tmp" 2>/dev/null || echo '[]')"
rm -f "$tmp"

jq -n --argjson entries "$entries" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{generated_at:$at, entries:$entries}' > "$registry"

exit 0
