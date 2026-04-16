#!/usr/bin/env bash
# Release a Project v2 lock on one item, or bulk-release all items held by a given owner.
#
# Usage A (one item): lock-release.sh \
#   --project <PID> --item <ITEM_ID> \
#   --owner-field <FID> --expiry-field <FID>
#
# Usage B (bulk by owner): lock-release.sh \
#   --project <PID> --owner-matches <LOCK_OWNER_STRING>
#
# Idempotent; always exits 0 unless invoked incorrectly.
set -euo pipefail

PROJECT=""; ITEM=""; OWNER_FIELD=""; EXPIRY_FIELD=""; OWNER_MATCH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)        PROJECT="$2"; shift 2;;
    --item)           ITEM="$2"; shift 2;;
    --owner-field)    OWNER_FIELD="$2"; shift 2;;
    --expiry-field)   EXPIRY_FIELD="$2"; shift 2;;
    --owner-matches)  OWNER_MATCH="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[[ -n "$PROJECT" ]] || { echo "--project required" >&2; exit 2; }

resolve_field_ids() {
  gh api graphql -f query='
    query($project: ID!) {
      node(id: $project) {
        ... on ProjectV2 {
          fields(first: 50) {
            nodes { ... on ProjectV2Field { id name } }
          }
        }
      }
    }
  ' -f project="$PROJECT" | jq -r '
    .data.node.fields.nodes
    | map(select(.name == "lock_owner" or .name == "lock_expires_at"))
    | map([.name, .id]) | .[] | @tsv
  '
}

if [[ -z "$OWNER_FIELD" || -z "$EXPIRY_FIELD" ]]; then
  while IFS=$'\t' read -r name fid; do
    [[ "$name" == "lock_owner" ]]     && OWNER_FIELD="$fid"
    [[ "$name" == "lock_expires_at" ]] && EXPIRY_FIELD="$fid"
  done < <(resolve_field_ids)
fi

[[ -n "$OWNER_FIELD" && -n "$EXPIRY_FIELD" ]] \
  || { echo "could not resolve lock field IDs on project" >&2; exit 2; }

clear_one() {
  local item_id="$1"
  gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $ownerField: ID!, $expiryField: ID!) {
      clearOwner: updateProjectV2ItemFieldValue(input: {
        projectId: $project, itemId: $item, fieldId: $ownerField,
        value: { text: "" }
      }) { clientMutationId }
      clearExpiry: updateProjectV2ItemFieldValue(input: {
        projectId: $project, itemId: $item, fieldId: $expiryField,
        value: { text: "" }
      }) { clientMutationId }
    }
  ' -f project="$PROJECT" -f item="$item_id" \
    -f ownerField="$OWNER_FIELD" -f expiryField="$EXPIRY_FIELD" >/dev/null || true
}

if [[ -n "$ITEM" ]]; then
  clear_one "$ITEM"
  echo "{\"released\":\"$ITEM\"}"
  exit 0
fi

if [[ -n "$OWNER_MATCH" ]]; then
  scan="$(dirname "$0")/project-query.sh"
  [[ -x "$scan" ]] || { echo "project-query.sh missing" >&2; exit 2; }

  cleared=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    owner=$(echo "$line" | jq -r '.lock_owner // ""')
    item_id=$(echo "$line" | jq -r '.item_id // ""')
    if [[ -n "$item_id" && "$owner" == *"$OWNER_MATCH"* ]]; then
      clear_one "$item_id"
      cleared=$((cleared + 1))
    fi
  done < <("$scan" "$PROJECT")

  echo "{\"released_count\":$cleared}"
  exit 0
fi

echo "either --item or --owner-matches required" >&2
exit 2
