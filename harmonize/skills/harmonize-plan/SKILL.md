---
name: harmonize-plan
description: >
  Interactive Phase 3 (Plan authoring) sub-skill for the harmonize SDLC. Loads when the user
  wants to author or revise an implementation plan for a merged design. Claims a coarse
  interactive lock on (phase=plan, subsystem), stops in-flight plan workers for that
  subsystem, walks the user through plan scoping questions, then spawns plan-author as a
  background task to write the plan files. The user never edits files directly. Used when
  the user invokes /harmonize plan, mentions authoring or revising a plan, or is loaded from
  the main harmonize skill.
---

# Harmonize — Plan (Interactive)

Interactive foreground path for Phase 3 plan authoring. The user decides plan scope and granularity;
`plan-author` does every file write.

## When to use

- User says "author a plan for X" or "revise PLAN-<id>"
- User wants to split a large plan into smaller ones
- User wants to decide dependencies between plans
- Loaded by `harmonize` skill when routing a plan request

## Load skills first

- `harmonize` — state files, lock protocol, phase-plan
- `document-templates` — implementation-plan, plan-progress templates

## Inputs

Via skill args:

- `subsystem` (optional)
- `design_path` (optional) — merged design doc driving the plan
- `plan_id` (optional) — if revising an existing plan

If missing, ask via `AskUserQuestion`.

## Execution flow

### 1. Create a main-level task

```text
TaskCreate({
  subject: "interactive plan: <subsystem>:<topic>",
  description: "User-driven Phase 3 plan authoring",
  activeForm: "Authoring plan for <subsystem>/<topic>",
  metadata: { owner: "main", skill: "harmonize-plan" }
})
```

### 2. Resolve target

Determine `subsystem` and the target design doc. If revising, load the existing plan file.

### 3. Check and claim the coarse lock

Read `docs/plans/locks.md`. Look for `(phase: plan, subsystem)`.

| State | Action |
|-------|--------|
| No lock | Claim it |
| Held by another | Ask user to wait, take over, or pick another |
| Stale (>24h) | Offer to release and reclaim |

Claim protocol:

1. Read `docs/plans/in-flight.md`
2. `TaskStop` all matching entries (`phase: plan, subsystem`)
3. Remove from `in-flight.md`
4. Append lock entry to `locks.md`
5. `rumdl fmt`, commit, push

### 4. Gather context

Read:

1. The merged design document at `design_path`
2. Companion test-cases file if present
3. Existing plans under `docs/plans/<subsystem>/` for ID collision avoidance
4. Root plan at `docs/plans/index.md`

Summarize in 3-5 bullets.

### 5. Guided plan Q&A

Ask via `AskUserQuestion`, one at a time:

1. **Decomposition** — How many leaf plans? What is each scope?
2. **Hierarchy** — Parent group plan needed? Sequential or parallel children?
3. **Dependencies** — Which plans must be merged before this one starts?
4. **Crate structure** — Which crates will this plan touch?
5. **Task granularity** — Roughly how many tasks per plan?
6. **Test cases** — Which TC-X.Y.Z entries drive red tests?

### 6. Confirm the write plan

Summarize the proposed plan tree:

```text
PLAN-<subsystem>-<topic> (group, sequential)
  ├── PLAN-<subsystem>-<topic>-<a>
  ├── PLAN-<subsystem>-<topic>-<b>
  └── PLAN-<subsystem>-<topic>-<c>
```

Ask for approval via `AskUserQuestion` (yes / edit / cancel).

### 7. Dispatch plan-author

```text
Agent({
  description: "plan-author <subsystem>:<topic>",
  subagent_type: "plan-author",
  prompt: "<full scope, decomposition, dependencies, design path, approved hierarchy>",
  run_in_background: true
})
```

Append to `in-flight.md`, commit.

### 8. Wait for completion

When plan-author completes:

1. `TaskOutput(task_id)` to read the summary
2. Show user the plan file paths, IDs, and PR URL
3. Ask whether to request changes or accept

### 9. Release the lock

1. Remove `(phase: plan, subsystem)` from `locks.md`
2. `rumdl fmt`, commit, push
3. Dispatch harmonize master agent in background to resume

### 10. Summarize

Complete the main task. Report plans written, PR URL, and suggested next step
(`/harmonize implement PLAN-<id>` once the plan PR merges).

## Never do

- Write plan files directly — plan-author does all writing
- Skip the lock claim
- Leave a lock behind
- Author plans without a merged design document
- Operate outside the claimed `(phase: plan, subsystem)`
