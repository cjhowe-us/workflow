#!/usr/bin/env bash
# Extend a Project v2 lock's lock_expires_at. Caller must already hold the lock.
#
# Usage: lock-heartbeat.sh \
#   --project <PID> --item <ITEM_ID> \
#   --expiry-field <FID> --expires-at <YYYY-MM-DDTHH:MM:SSZ> \
#   [--owner-field <FID> --expected-owner <OWNER>]
#
# If --owner-field and --expected-owner are given, the current owner is verified first
# and the call fails (exit 1) if the lock has been stolen.
set -euo pipefail

PROJECT=""; ITEM=""; EXPIRY_FIELD=""; EXPIRY=""
OWNER_FIELD=""; EXPECTED_OWNER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)         PROJECT="$2"; shift 2;;
    --item)            ITEM="$2"; shift 2;;
    --expiry-field)    EXPIRY_FIELD="$2"; shift 2;;
    --expires-at)      EXPIRY="$2"; shift 2;;
    --owner-field)     OWNER_FIELD="$2"; shift 2;;
    --expected-owner)  EXPECTED_OWNER="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
for v in PROJECT ITEM EXPIRY_FIELD EXPIRY; do
  [[ -n "${!v}" ]] || { echo "$v required" >&2; exit 2; }
done

if [[ -n "$OWNER_FIELD" && -n "$EXPECTED_OWNER" ]]; then
  cur_owner=$(gh api graphql -f query='
    query($item: ID!) {
      node(id: $item) {
        ... on ProjectV2Item {
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2Field { name } } }
            }
          }
        }
      }
    }
  ' -f item="$ITEM" | jq -r '
    [.data.node.fieldValues.nodes[] | select(.field.name == "lock_owner") | .text] | .[0] // ""
  ')
  if [[ "$cur_owner" != "$EXPECTED_OWNER" ]]; then
    echo "stolen: current owner is '$cur_owner' (expected '$EXPECTED_OWNER')" >&2
    exit 1
  fi
fi

gh api graphql -f query='
  mutation($project: ID!, $item: ID!, $expiryField: ID!, $expiry: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $project, itemId: $item, fieldId: $expiryField, value: { text: $expiry }
    }) { clientMutationId }
  }
' -f project="$PROJECT" -f item="$ITEM" \
  -f expiryField="$EXPIRY_FIELD" -f expiry="$EXPIRY" >/dev/null

echo "{\"heartbeat\":\"ok\",\"expires_at\":\"$EXPIRY\"}"
