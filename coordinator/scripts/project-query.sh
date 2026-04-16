#!/usr/bin/env bash
# Query a GitHub Project v2 for every PR in scope, including lock fields,
# phase label, and `blocked by` relationships. Emits one JSON record per line.
#
# Only pull requests are emitted — issues are filtered out because the
# coordinator model uses PRs as the sole unit of work.
#
# Usage: project-query.sh <PROJECT_ID>
set -euo pipefail

PROJECT_ID="${1:?PROJECT_ID required}"

if ! command -v gh >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "gh and jq are required" >&2
  exit 2
fi

QUERY='
    query($project: ID!, $after: String) {
      node(id: $project) {
        ... on ProjectV2 {
          items(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                __typename
                ... on PullRequest {
                  number state isDraft
                  repository { nameWithOwner }
                  headRefName
                  labels(first: 20) { nodes { name } }
                }
              }
              fieldValues(first: 50) {
                nodes {
                  __typename
                  ... on ProjectV2ItemFieldTextValue {
                    text field { ... on ProjectV2Field { name } }
                  }
                }
              }
            }
          }
        }
      }
    }
  '

cursor=""
while :; do
  if [[ -n "$cursor" ]]; then
    resp=$(gh api graphql -f query="$QUERY" -f project="$PROJECT_ID" -f after="$cursor")
  else
    resp=$(gh api graphql -f query="$QUERY" -f project="$PROJECT_ID")
  fi

  echo "$resp" | jq -c '
    .data.node.items.nodes[]
    | select(.content.__typename == "PullRequest")
    | . as $it
    | ($it.fieldValues.nodes // [])
      | (map(select(.field.name == "lock_owner")
             | .text) | .[0] // "") as $lock_owner
    | ($it.fieldValues.nodes // [])
      | (map(select(.field.name == "lock_expires_at")
             | .text) | .[0] // "") as $lock_expires_at
    | ($it.content.labels.nodes // [])
      | (map(select(.name | startswith("phase:")) | .name[6:])
         | .[0] // "") as $phase
    | {
        item_id:         $it.id,
        number:          $it.content.number,
        repo:            $it.content.repository.nameWithOwner,
        state:           ($it.content.state // "" | ascii_downcase),
        is_draft:        ($it.content.isDraft // false),
        head_ref_name:   ($it.content.headRefName // null),
        phase:           $phase,
        lock_owner:      $lock_owner,
        lock_expires_at: $lock_expires_at
      }
  '

  has_next=$(echo "$resp" | jq -r '.data.node.items.pageInfo.hasNextPage')
  cursor=$(echo "$resp" | jq -r '.data.node.items.pageInfo.endCursor')
  [[ "$has_next" == "true" ]] || break
done
