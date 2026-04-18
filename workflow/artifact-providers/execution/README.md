# execution provider

Backs `execution:` artifacts — the canonical record of a workflow run.

## Backend mapping

The default backend is GitHub. An execution maps 1:1 with a PR:

| Execution field    | Backed by                                       |
|--------------------|-------------------------------------------------|
| uri                | `execution:<repo>/<pr-number>`                  |
| status             | PR state (open → running, merged → complete, closed-without-merge → aborted) |
| owner              | PR assignee                                     |
| description        | PR body section tagged `<!-- wf:summary -->`    |
| step ledger        | PR body section tagged `<!-- wf:ledger -->` (compact JSON) |
| progress log       | PR comments tagged `<!-- wf:progress -->`       |

The PR body is rewritten on step transitions (summary + ledger are regenerated). Progress events are
append-only as new comments — each comment carries a single JSON payload in an HTML comment,
followed by a human-readable line for the PR page.

## Subcommand semantics

- `get --uri U` — fetch PR body + parse wf sections → full execution state.
- `create --data F` — open a fresh PR (draft by default), populate the wf sections from `F`, return
  `{"uri": "execution:<repo>/<n>"}`.
- `update --uri U --patch F` — rewrite the wf sections of the PR body preserving any user-authored
  prose outside those markers.
- `list --filter F` — `gh pr list --state open --search "workflow:"` style query; filter by label,
  author, or wf:summary fields.
- `lock --uri U --owner O` — set PR assignee. `--check` compares without mutating. Single-assignee
  enforcement relies on GitHub.
- `release --uri U --owner O` — clear PR assignee (if current matches O).
- `status --uri U` — map PR state to the lifecycle enum.
- `progress --uri U` — fetch all wf:progress comments, extract JSON, return as `entries`.
- `progress --uri U --append F` — post a new comment with the JSON payload plus a human line.

## Error paths

- GitHub API 404 on `get` → `{"error":"not-found"}` + exit 2.
- GitHub API 403 / rate-limit → `{"error":"rate-limited","retry_after":N}`
  - exit 3.
- Lock mismatch on `update` (someone else is the assignee) →
  `{"error": "lock-mismatch","current_owner":"..."}` + exit 4.

Retryable errors (rate limit) are returned to the caller; the worker surfaces as a blocker and
doesn't auto-retry.

## PR body template

```markdown
<!-- wf:summary {version:1, execution_id:"...", definition:"...", started_at:"...", status:"running"} -->
# bug-fix / exec-A

Short human summary written by the default orchestrator on each transition.

## Current step

`fix` — in progress since 2026-04-18T09:24:00Z

## Context

- Item: #42
- Base: main

<!-- wf:ledger {
  "steps": [
    { "step": "triage", "signature": "...", "completed_at": "...", "artifacts": [...] },
    { "step": "fix",    "signature": "...", "status": "running",  "artifacts": [...] }
  ]
} -->
```

A worker updating the PR body preserves prose outside the `wf:*` markers. This is how human-authored
notes on the PR survive step transitions.

## Idempotency

`update` uses If-Match on the PR body's ETag (via `gh api`); a conflict triggers a retry once after
re-reading the body. A second conflict returns the lock-mismatch error rather than clobbering
another writer's edits.
