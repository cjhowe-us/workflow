---
name: lock-protocol
description: >
  GraphQL recipes for acquiring, heartbeating, and releasing the Project v2
  lock on a pull request via two text custom fields: `lock_owner` and
  `lock_expires_at` (ISO-8601 UTC timestamp). Includes race mitigation via
  read-back verification and the stale-lock reclaim rule. Used by the
  `coordinator` orchestrator and `coordinator-worker` agent. PRs are the only
  locked resource — there are no issue locks.
---

# Lock protocol

GitHub Project v2 is the single source of truth. Every PR in scope carries two **text** custom
fields:

| Field             | Type | Meaning                                                              |
|-------------------|------|----------------------------------------------------------------------|
| `lock_owner`      | Text | `<machine-id>:<orchestrator-session-id>:<worker-agent-id>`. Empty = unlocked. |
| `lock_expires_at` | Text | ISO-8601 UTC timestamp, e.g. `2026-04-16T18:45:00Z`. Empty or lexicographically `< now` = stale. |

Both fields are **Text** because Project v2 has no DateTime field and Date is day-granular, which is
too coarse for real-time locks. ISO-8601 Zulu UTC sorts lexicographically in the same order as by
actual time, so string comparison is valid for expiry checks.

No start-timestamp is stored. Expirations are absolute instants set by the worker; the GitHub item
timeline records when the lock was first set.

## Field ID lookup (one-time per session)

Cache the Project v2 node ID and the two field IDs:

```bash
gh api graphql -f query='
query($project: ID!) {
  node(id: $project) {
    ... on ProjectV2 {
      fields(first: 50) {
        nodes { ... on ProjectV2Field { id name } }
      }
    }
  }
}' -f project="$PROJECT_ID" \
  | jq -r '.data.node.fields.nodes[] | [.name, .id] | @tsv'
```

Extract `lock_owner` and `lock_expires_at` field IDs. Error out loudly if either is missing —
operator must create them as Text fields first (see plugin README).

## Acquire

Called by the worker once per assignment for its PR's Project v2 item:

1. **Read current lock**

   ```bash
   gh api graphql -f query='
   query($item: ID!) {
     node(id: $item) {
       ... on ProjectV2Item {
         fieldValues(first: 20) {
           nodes {
             ... on ProjectV2ItemFieldTextValue {
               field { ... on ProjectV2Field { name } } text
             }
           }
         }
       }
     }
   }' -f item="$ITEM_ID"
   ```

2. **Abort if held**: if `lock_owner` non-empty AND `lock_expires_at > now_iso`, another worker
   holds it. Do not write — `SendMessage` the orchestrator `{status: "raced", pr_number: <M>}` and
   stop.

3. **Compute expiry**: `NEW_EXPIRES_AT = $(date -u -v +<N>M +"%Y-%m-%dT%H:%M:%SZ")` (BSD) or
   `date -u -d "+<N> minutes" +"%Y-%m-%dT%H:%M:%SZ"` (GNU). `<N>` defaults to 15 (minutes); worker
   picks based on expected work length.

4. **Write both fields** in one GraphQL request with two aliased mutations:

   ```bash
   gh api graphql -f query='
   mutation(
     $project: ID!, $item: ID!,
     $ownerField: ID!, $owner: String!,
     $expiryField: ID!, $expiry: String!
   ) {
     setOwner: updateProjectV2ItemFieldValue(input: {
       projectId: $project, itemId: $item, fieldId: $ownerField,
       value: { text: $owner }
     }) { clientMutationId }
     setExpiry: updateProjectV2ItemFieldValue(input: {
       projectId: $project, itemId: $item, fieldId: $expiryField,
       value: { text: $expiry }
     }) { clientMutationId }
   }' -f project="$PROJECT_ID" -f item="$ITEM_ID" \
     -f ownerField="$OWNER_FIELD_ID" -f owner="$LOCK_OWNER" \
     -f expiryField="$EXPIRY_FIELD_ID" -f expiry="$NEW_EXPIRES_AT"
   ```

5. **Race mitigation** — after a 100–500ms randomized delay, re-read. If
   `lock_owner != $LOCK_OWNER`, another worker raced. Release your half-write (write empty string on
   both fields) and report `raced`.

## Heartbeat

Called by the worker on its own schedule, before `lock_expires_at - 60s`:

```bash
gh api graphql -f query='
mutation($project: ID!, $item: ID!, $expiryField: ID!, $expiry: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $expiryField,
    value: { text: $expiry }
  }) { clientMutationId }
}' -f project="$PROJECT_ID" -f item="$ITEM_ID" \
  -f expiryField="$EXPIRY_FIELD_ID" -f expiry="$NEW_EXPIRES_AT"
```

Do not re-write `lock_owner`. Each heartbeat extends the lease only.

If the worker reads and finds `lock_owner != $LOCK_OWNER` before heartbeating, another actor has
stolen the lock (should not happen under the protocol, but possible if a human edited the field).
Stop work immediately.

## Release

On worker finish or via `hooks/release-lock-on-stop.sh`:

```bash
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
}' -f project="$PROJECT_ID" -f item="$ITEM_ID" \
  -f ownerField="$OWNER_FIELD_ID" -f expiryField="$EXPIRY_FIELD_ID"
```

Idempotent: if already cleared, mutation still succeeds.

## Stale reclaim

Orchestrator during scan treats `lock_expires_at < now_iso` (string compare on Zulu ISO-8601) as
*logically unlocked* but does **not** clear the field. The next worker's acquire overwrites both
fields in a single mutation pair.

## Never

- Clear another worker's lock directly. Only the owning worker (or its stop hook) releases.
- Acquire without reading first — always read-then-write-then-read-back.
- Store the lock start time. Only the absolute expiration lives in GitHub.
- Heartbeat after a worker has reported `done` — release is terminal.
- Use the Date field type. Day granularity is too coarse and compare semantics differ between
  representations.
- Lock any resource other than a PR. Issues, drafts, and discussions are out of scope.
