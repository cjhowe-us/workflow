# running

How to dispatch, track, and manage running workflows. Covers
`run`/`start`/`resume`/`retry`/`skip`/`abort`, WIP caps, retry-blocker- needs_attention semantics,
and the role of the `workflow-execution` artifact template.

## Starting a workflow

The `/workflow run <name> [inputs...]` path composes one step: the `workflow-execution` artifact
template with `workflow=<name>` and `workflow_inputs=<rendered>`. That template:

1. Resolves the workflow against the registry (respecting scope precedence).
2. Validates `workflow_inputs` against the workflow's declared inputs contract. Missing required →
   blocker; wrong type → blocker.
3. Opens the underlying execution artifact via the configured provider (default `gh-pr`): PR is
   created, drafted, assigned to current `gh auth` user, seeded with the wf:summary + wf:ledger
   sections.
4. Returns the new `execution:<repo>/<n>` URI.

The orchestrator then spawns a worker teammate at the new worktree to run the workflow's graph
step-by-step.

## Resume

`/workflow resume <change>` loads the execution's provider state, reconstructs its current step from
the ledger, and dispatches a worker to continue. Nothing else changes — progress is already
preserved by the provider.

## Retry, skip, abort

Three resolution paths when a step is not-complete:

- **retry** — reset the step's retry count to 0, re-dispatch. Used when the original failure is
  already fixed.
- **skip** — mark the step `complete` with `skipped: true` and a reason. Downstream steps must
  tolerate skip (declared in their preconditions) or they will in turn surface as blockers.
- **abort** — the only terminal state. Closes the underlying execution artifact (gh-pr closes the PR
  without merging). User confirms.

## Retry cap, blockers, needs_attention

Step-level states reported by `execution.status`:

- `pending` — not started.
- `running` — worker in the worktree right now.
- `blocked` — an unresolved gate or an explicit `cmd: blocker` emitted by the worker. Waiting for
  user input; not broken.
- `needs_attention` — retries exhausted (provider cap, default 3) or an unresolvable runtime error.
  Progress is NOT lost; the user debugs (often via `/workflow tunnel <worker>`) and then retries,
  skips, or aborts.
- `complete` — step succeeded.

Workflow-level status mirrors the worst active step (except `complete`, which requires all steps
complete).

## WIP caps

Advisory caps enforced by the default orchestrator at dispatch time.

| Dimension                           | Default | Source                          |
|-------------------------------------|---------|---------------------------------|
| Concurrent executions per developer | 3       | `wip.per_developer` (session)   |
| Concurrent worktrees per machine    | 8       | `wip.per_machine`               |
| Concurrent steps per execution      | 4       | `wip.per_execution`             |

Per-workflow override: a workflow may declare `wip: { per_execution: N }` in its frontmatter. The
other caps are global.

### Tuning

- `/workflow limit <N>` — convenience alias for the per-developer cap.
- `preferences:user` — tune any cap interactively via the `preferences` provider
  (`/artifact show preferences:user` to inspect).

### Why caps exist

To prevent runaway dispatch from flooding a developer's machine (exhausting fd/disk/process budgets)
or their GitHub PR list. Caps are a throttle, not a safety mechanism — artifact locks enforce
correctness.

## Release (lock transfer)

`/workflow release <change>` clears the PR assignee. The lock is then free to be re-acquired by
another developer (who assigns themselves via `gh pr edit --add-assignee @me`). No automatic
transfer; see the `multi-dev` reference.

## Parent / child executions

A parent's composed step dispatches a child execution via the same `workflow-execution` template
path. The parent and child run in parallel on disjoint worktrees. The parent polls the child's
`execution.status` until `complete` (or a terminal state), then merges the child's PR into the
parent's branch.

Children never lock the parent. Children cannot write to the parent's worktree or execution state.

## Progress reporting

- `PostToolUse` hook auto-appends a progress entry to the current execution every time a worker runs
  `Edit` / `Write` / `Bash`.
- Workers may emit additional progress entries explicitly via
  `{"cmd":"progress","message":"...","at":"..."}` in a SendMessage.
- Dashboard queries (`/workflow status`) fetch progress fresh from the provider; no caches, no
  staleness.

## Retroactive steps (no missed migrations)

When a workflow definition gains a new step after some executions have already completed, the
`running` flow's scan pass diffs each execution's step ledger against the current definition and
flags any missing step as `retroactive-pending`. The user can backfill via
`/workflow retry <change> <new-step>` which spawns a worker targeting only that step. Progress is
append-only; backfill never rewinds prior work.
