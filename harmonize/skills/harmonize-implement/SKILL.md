---
name: harmonize-implement
description: >
  Interactive Phase 3 (Implementation) sub-skill for the harmonize SDLC. Loads when the user
  wants to step through a plan's TDD execution interactively. Claims a coarse interactive
  lock on (phase=plan, subsystem), stops the in-flight plan-implementer for that plan,
  coordinates with plan-implementer in foreground (one step at a time, with user approval
  between steps) OR dispatches plan-implementer to run autonomously with the user observing.
  The user never edits files directly. Used when the user invokes /harmonize implement,
  mentions stepping through an implementation, or is loaded from the main harmonize skill.
---

# Harmonize — Implement (Interactive)

Interactive foreground path for Phase 3 implementation. The user decides pace (step-by-step or
run-to-completion); `plan-implementer` drives the TDD loop. Every file write and git operation
happens inside the worktree by `plan-implementer`.

## When to use

- User says "step through PLAN-<id>" or "let me watch the ECS implementation"
- User wants to review each red test + green implementation before the next cycle
- User wants to pause a running implementation and take over
- Loaded by `harmonize` skill when routing an implement request

## Load skills first

- `harmonize` — state files, lock protocol, plan schemas
- `document-templates` — implementation-plan, plan-progress

## Inputs

Via skill args:

- `plan_id` (required) — e.g., `PLAN-core-ecs-archetype`
- `mode` (optional) — `step` (approve each task) | `run` (run to completion, observe only)

If missing, ask via `AskUserQuestion`.

## Execution flow

### 1. Create a main-level task

```text
TaskCreate({
  subject: "interactive implement: <plan_id>",
  description: "User-driven Phase 3 TDD execution",
  activeForm: "Implementing <plan_id>",
  metadata: { owner: "main", skill: "harmonize-implement" }
})
```

### 2. Load plan state

- Read `docs/plans/<subsystem>/<topic>.md` — the plan file
- Read `docs/plans/progress/<plan_id>.md` — the progress file
- Confirm the plan's design documents are merged
- Confirm all dependencies are `merged` (status=done)

If prerequisites fail, stop and explain to the user.

### 3. Check and claim the coarse lock

The lock is `(phase: plan, subsystem)` — the same lock as plan authoring. This is deliberate: if the
user is implementing, they are also implicitly owning the plan for that subsystem.

Claim protocol:

1. Read `docs/plans/in-flight.md`
2. For every in-flight entry with `worker_agent: plan-implementer` and matching `subsystem`, call
   `TaskStop(task_id)` (the user is taking over)
3. Remove those entries
4. Append `(phase: plan, subsystem)` lock to `locks.md`
5. `rumdl fmt`, commit, push

### 4. Show plan context

Summarize for the user:

- Plan ID and name
- Task breakdown (count + names)
- Current status from progress file
- Worktree path
- PR URL if already opened

### 5. Decide mode

Ask via `AskUserQuestion`:

| Mode | Behavior |
|------|----------|
| `step` | Before each task, ask the user to approve. Implementer pauses for feedback |
| `run` | Implementer runs to completion. User observes and can intervene via `/stop` |

### 6. Dispatch or resume plan-implementer

For `step` mode:

Dispatch `plan-implementer` with a prompt instructing it to pause after each task and write an
explicit `step completed: task N` marker to its progress file. Read the progress file on each update
and show the user.

For `run` mode:

Dispatch `plan-implementer` to run all tasks:

```text
Agent({
  description: "plan-implementer <plan_id>",
  subagent_type: "plan-implementer",
  prompt: "<plan_id, plan_path, run-to-completion>",
  run_in_background: true
})
```

Append to `in-flight.md`.

### 7. Observe + interact

For `step` mode: read progress file updates, show each task's diff to the user, ask whether to
continue (`next` / `skip` / `stop`). Communicate with the implementer via progress file checkpoints
(it reads on each task boundary).

For `run` mode: periodically show progress updates to the user. User can interrupt to change mode or
give feedback.

### 8. Completion

When `plan-implementer` reaches `code_complete`:

1. Read the final `TaskOutput`
2. Show the user the PR URL and summary
3. Ask whether to dispatch `pr-reviewer` now or wait for the background orchestrator

### 9. Release the lock

1. Remove the entry from `locks.md`
2. `rumdl fmt`, commit, push
3. Dispatch harmonize master agent in background to resume

### 10. Summarize

Report: plan ID, PR URL, tests passing, any deferrals. Complete main task.

## Never do

- Write code directly — plan-implementer does all TDD
- Skip the lock claim
- Leave a lock behind
- Force plan-implementer to run if tests are failing
- Operate outside the claimed plan's subsystem
