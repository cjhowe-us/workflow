#!/usr/bin/env bash
# Acquire a Project v2 lock on a single item.
#
# Usage: lock-acquire.sh \
#   --project <PROJECT_ID> --item <ITEM_ID> \
#   --owner-field <OWNER_FIELD_ID> --expiry-field <EXPIRY_FIELD_ID> \
#   --owner <LOCK_OWNER_STRING> --expires-at <YYYY-MM-DDTHH:MM:SSZ>
#
# Exit 0 on success. Exit 1 on race (another owner holds). Exit 2 on error.
set -euo pipefail

PROJECT=""; ITEM=""; OWNER_FIELD=""; EXPIRY_FIELD=""; OWNER=""; EXPIRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)      PROJECT="$2"; shift 2;;
    --item)         ITEM="$2"; shift 2;;
    --owner-field)  OWNER_FIELD="$2"; shift 2;;
    --expiry-field) EXPIRY_FIELD="$2"; shift 2;;
    --owner)        OWNER="$2"; shift 2;;
    --expires-at)   EXPIRY="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
for v in PROJECT ITEM OWNER_FIELD EXPIRY_FIELD OWNER EXPIRY; do
  [[ -n "${!v}" ]] || { echo "$v required" >&2; exit 2; }
done

now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

read_lock() {
  gh api graphql -f query='
    query($item: ID!) {
      node(id: $item) {
        ... on ProjectV2Item {
          fieldValues(first: 50) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2Field { name } } }
            }
          }
        }
      }
    }
  ' -f item="$ITEM"
}

current=$(read_lock)
cur_owner=$(echo "$current" | jq -r '[.data.node.fieldValues.nodes[] | select(.field.name == "lock_owner") | .text] | .[0] // ""')
cur_expiry=$(echo "$current" | jq -r '[.data.node.fieldValues.nodes[] | select(.field.name == "lock_expires_at") | .text] | .[0] // ""')

# ISO-8601 Zulu UTC sorts lexicographically in the same order as by time, so a plain
# string compare against now_iso is a valid expiry check.
if [[ -n "$cur_owner" && -n "$cur_expiry" && "$cur_expiry" > "$now_iso" ]]; then
  echo "raced: held by $cur_owner until $cur_expiry" >&2
  exit 1
fi

gh api graphql -f query='
  mutation(
    $project: ID!, $item: ID!,
    $ownerField: ID!, $owner: String!,
    $expiryField: ID!, $expiry: String!
  ) {
    setOwner: updateProjectV2ItemFieldValue(input: {
      projectId: $project, itemId: $item, fieldId: $ownerField, value: { text: $owner }
    }) { clientMutationId }
    setExpiry: updateProjectV2ItemFieldValue(input: {
      projectId: $project, itemId: $item, fieldId: $expiryField, value: { text: $expiry }
    }) { clientMutationId }
  }
' -f project="$PROJECT" -f item="$ITEM" \
  -f ownerField="$OWNER_FIELD" -f owner="$OWNER" \
  -f expiryField="$EXPIRY_FIELD" -f expiry="$EXPIRY" >/dev/null

# Random backoff 100-500ms, then verify ownership. sleep(1) on macOS/BSD accepts
# fractional seconds.
sleep "0.$(printf '%03d' $((RANDOM % 400 + 100)))"

verify=$(read_lock)
ver_owner=$(echo "$verify" | jq -r '[.data.node.fieldValues.nodes[] | select(.field.name == "lock_owner") | .text] | .[0] // ""')
if [[ "$ver_owner" != "$OWNER" ]]; then
  # Someone else raced to overwrite after our write. Release our half-stamp and bail.
  "$(dirname "$0")/lock-release.sh" \
    --project "$PROJECT" --item "$ITEM" \
    --owner-field "$OWNER_FIELD" --expiry-field "$EXPIRY_FIELD" >/dev/null 2>&1 || true
  echo "raced: overwritten by $ver_owner after write" >&2
  exit 1
fi

printf '{"acquired":true,"owner":"%s","expires_at":"%s","at":"%s"}\n' \
  "$OWNER" "$EXPIRY" "$now_iso"
