---
name: harmonize-specify
description: >
  Interactive Phase 1 (Specify) sub-skill for the harmonize SDLC. Loads when the user wants to
  author or revise features, requirements, or user stories interactively. Claims a coarse
  interactive lock on (phase=specify, subsystem), stops any in-flight specify workers for that
  subsystem, walks the user through guided questions, then spawns feature-author,
  requirement-author, and user-story-author as background agents to do all file writes. The
  user never edits files directly. Used when the user invokes /harmonize specify, mentions
  authoring or revising F/R/US, or is loaded from the main harmonize skill.
---

# Harmonize — Specify (Interactive)

Interactive foreground path for Phase 1. The user decides and gives feedback; background agents do
every file write.

## When to use

- User says "I want to ideate X" or "revise the F/R/US for Y"
- User wants to explore alternatives before committing
- Loaded by `harmonize` skill when routing a specify request

## Load skills first

- `harmonize` — for state file locations, the coarse lock protocol, per-phase progress
- `document-templates` — for the feature / requirement / user-story templates

## Inputs

Via skill args:

- `subsystem` (optional) — e.g., `ai`
- `topic` (optional) — filename stem or free-text idea

If missing, ask via `AskUserQuestion`.

## Execution flow

### 1. Create a main-level task

```text
TaskCreate({
  subject: "interactive specify: <subsystem>:<topic>",
  description: "User-driven Phase 1 ideation",
  activeForm: "Ideating <subsystem>/<topic>",
  metadata: { owner: "main", skill: "harmonize-specify" }
})
```

### 2. Resolve target subsystem

If the topic maps to existing F/R/US files, read them first to give context. Determine the target
`subsystem` identifier.

### 3. Check and claim the coarse lock

Read `docs/plans/locks.md`. Look for an entry where `phase: specify` and
`subsystem: <target_subsystem>`.

| State | Action |
|-------|--------|
| No lock | Claim it |
| Lock held by another session | Ask user whether to wait, take over, or pick another subsystem |
| Stale lock (>24h) | Offer to release and reclaim |

#### Claim protocol

1. Read `docs/plans/in-flight.md`
2. For each in-flight entry with `phase: specify && subsystem: <target>`, call `TaskStop`
3. Remove those entries from `in-flight.md`
4. Append a lock entry to `locks.md`:

   ```yaml
   - phase: specify
     subsystem: <target>
     claimed_at: <ISO 8601 UTC now>
     owner: harmonize-specify
     reason: <short reason from user or "interactive ideation">
   ```

5. Run `rumdl fmt docs/plans/locks.md` then commit the lock change:

   ```bash
   git add docs/plans/locks.md docs/plans/in-flight.md
   git commit -m "[specify] claim lock for <subsystem>"
   git push
   ```

### 4. Gather context for the user

Read, in order:

1. Any existing `docs/features/<subsystem>/<topic>.md` or nearby files
2. Related design docs under `docs/design/<subsystem>/`
3. `docs/architecture.md` for the subsystem's dependencies

Summarize the context in ~3 bullet points before asking questions.

### 5. Guided Q&A

Ask via `AskUserQuestion`, one focused question at a time:

1. **Scope** — Single feature or multiple?
2. **Rationale** — Why does this exist? Whose problem?
3. **Persona** — Which persona(s) drive this?
4. **Acceptance** — How will we know it is done?
5. **Verification** — How will we test each criterion?
6. **Alternatives** — What other designs were considered?
7. **Cross-references** — What does it depend on?

Each question's response becomes context for the spawned workers.

### 6. Confirm the write plan

Summarize for the user:

- Which files will be written (feature, requirement, user-story)
- Which branches/PRs each worker will open
- The tentative F-X.Y.Z / R-X.Y.Z / US-X.Y.Z IDs

Ask for approval via `AskUserQuestion` (yes / edit / cancel). On cancel, go to step 9 (release
lock).

### 7. Dispatch background workers

Dispatch the three authors as background sub-agents in parallel — they will handle all file writes,
commits, and PRs. The user never edits anything directly.

```text
Agent({
  description: "feature-author for <subsystem>:<topic>",
  subagent_type: "feature-author",
  prompt: "<full topic description + user answers + target paths>",
  run_in_background: true
})
Agent({
  description: "requirement-author for <subsystem>:<topic>",
  subagent_type: "requirement-author",
  prompt: "<...>",
  run_in_background: true
})
Agent({
  description: "user-story-author for <subsystem>:<topic>",
  subagent_type: "user-story-author",
  prompt: "<...>",
  run_in_background: true
})
```

For each dispatched task, append an entry to `docs/plans/in-flight.md` with `task_id`,
`worker_agent`, `phase: specify`, `subsystem`, `started_at`. Commit the in-flight update.

### 8. Wait for completion notifications

The three background tasks surface completion notifications to this foreground session as they
finish. For each notification:

1. Call `TaskOutput(task_id)` to read the summary
2. Show the user the file path, IDs, and PR URL
3. Ask whether to request changes (re-dispatch worker with correction) or accept

Keep the user in the conversation while the workers run. The user can pause, ask follow-up
questions, or jump to another task — but the lock stays claimed until they explicitly finish.

### 9. Release the lock

When the user is done (or cancels):

1. Remove the lock entry from `docs/plans/locks.md`
2. Run `rumdl fmt docs/plans/locks.md`
3. Commit:

   ```bash
   git add docs/plans/locks.md
   git commit -m "[specify] release lock for <subsystem>"
   git push
   ```

4. Dispatch the harmonize master agent in background to resume:

   ```text
   Agent({
     description: "Resume harmonize after specify release",
     subagent_type: "harmonize",
     prompt: "resume specify <subsystem>",
     run_in_background: true
   })
   ```

### 10. Summarize for the user

Complete the main task. Report:

- Files created or revised
- F/R/US IDs assigned
- PR URLs (for human review on GitHub)
- Suggested next step (usually: `/harmonize design <subsystem>`)

## Never do

- Write files directly — workers do all writing
- Skip the lock claim
- Leave a lock behind when exiting
- Dispatch phase workers without user approval of the write plan
- Operate outside the claimed subsystem
