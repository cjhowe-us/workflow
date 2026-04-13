---
name: harmonize-design
description: >
  Interactive Phase 2 (Design) sub-skill for the harmonize SDLC. Loads when the user wants to
  author or revise a subsystem design, interface design, component details, or integration
  design interactively. Claims a coarse interactive lock on (phase=design, subsystem), stops
  in-flight design workers for that subsystem, walks the user through guided design
  questions, then spawns subsystem-designer / interface-designer / component-designer /
  integration-designer as background agents to do all file writes. The user never edits
  files directly. Used when the user invokes /harmonize design, mentions authoring or
  revising a design, or is loaded from the main harmonize skill.
---

# Harmonize — Design (Interactive)

Interactive foreground path for Phase 2. The user decides architecture + API tradeoffs; background
agents do every file write and commit.

## When to use

- User says "let's design X" or "revise the ECS design"
- User wants to explore design alternatives before committing
- User wants to review and guide an in-progress design
- Loaded by `harmonize` skill when routing a design request

## Load skills first

- `harmonize` — state files, lock protocol, per-phase progress
- `document-templates` — design-document, integration-design templates
- `rust` — coding standard for API sections

## Inputs

Via skill args:

- `subsystem` (optional)
- `topic` (optional) — filename stem or design path
- `level` (optional) — `subsystem` | `interface` | `component` | `integration`

If missing, ask via `AskUserQuestion`.

## Execution flow

### 1. Create a main-level task

```text
TaskCreate({
  subject: "interactive design: <subsystem>:<topic>",
  description: "User-driven Phase 2 design",
  activeForm: "Designing <subsystem>/<topic>",
  metadata: { owner: "main", skill: "harmonize-design" }
})
```

### 2. Resolve target

Determine `subsystem`, `topic`, and which `level` of work (subsystem-wide doc, interface detail,
component detail, or integration). For integration, ask which subsystems are involved.

### 3. Check and claim the coarse lock

Read `docs/plans/locks.md`. Look for `(phase: design, subsystem: <target>)`.

| State | Action |
|-------|--------|
| No lock | Claim it |
| Held by another session | Ask user to wait, take over, or pick another subsystem |
| Stale (>24h) | Offer to release and reclaim |

#### Claim protocol

1. Read `docs/plans/in-flight.md`
2. Call `TaskStop` on every in-flight entry matching `(phase: design, subsystem)`
3. Remove those entries from `in-flight.md`
4. Append a lock entry to `locks.md`
5. Run `rumdl fmt docs/plans/locks.md`
6. Commit + push the lock change

### 4. Gather context for the user

Read:

1. Any existing design doc at `docs/design/<subsystem>/<topic>.md`
2. Feature / requirement / user-story files for the subsystem
3. Sibling designs under `docs/design/<subsystem>/`
4. `docs/architecture.md` — dependencies of this subsystem
5. `docs/design/constraints.md` — absolute constraints

Summarize in 3-5 bullet points before Q&A.

### 5. Guided design Q&A

Ask one focused question at a time via `AskUserQuestion`. Adapt to `level`:

**For `level: subsystem` (top-level):**

1. **Scope** — What does this subsystem own? What does it NOT own?
2. **Architecture** — What are the module boundaries?
3. **Data flow** — How does data move through the subsystem per frame?
4. **Platform** — Any platform-specific concerns (macOS / Windows / Linux / iOS / Android)?
5. **Test strategy** — Unit / integration / benchmark coverage plan?
6. **Open questions** — What is still ambiguous?

**For `level: interface`:**

1. Which public types / traits / functions does this expose?
2. What are the error conditions and error types?
3. What is the ownership / borrow model?
4. Are any items generic / trait-bound?
5. How do tests exercise the interface?

**For `level: component`:**

1. What internal data structures are used?
2. What are the perf / memory targets (numeric)?
3. Hot path characteristics (allocation-free, lock-free, deterministic)?
4. What algorithms? (link to sources)

**For `level: integration`:**

1. Which subsystems are involved and in what roles?
2. What shared types cross the boundary? Who owns them?
3. What is the data flow direction?
4. What game loop phase does the integration run in?
5. What are the failure modes?

### 6. Confirm the write plan

Summarize for the user:

- Which design file(s) will be written / revised
- Which worker agent(s) will run (subsystem-designer, interface-designer, etc.)
- Which draft PR(s) each will open

Ask for approval via `AskUserQuestion` (yes / edit / cancel).

### 7. Dispatch background workers

Dispatch the selected worker(s) in parallel via `Agent(run_in_background: true)`. Append each to
`in-flight.md`. Commit the in-flight update.

### 8. Wait for completion notifications

For each completion:

1. `TaskOutput(task_id)` → read summary
2. Show user the file path, PR URL, and any open questions
3. Ask whether to request changes (re-dispatch) or accept

If the user requests an immediate automated review, dispatch `design-reviewer` and report findings
when they arrive.

### 9. Release the lock

1. Remove entry from `locks.md`
2. `rumdl fmt`, commit, push
3. Dispatch harmonize master agent in background:

   ```text
   Agent({
     description: "Resume harmonize after design release",
     subagent_type: "harmonize",
     prompt: "resume design <subsystem>",
     run_in_background: true
   })
   ```

### 10. Summarize

Complete the main task. Report files written, PR URLs, any unresolved questions, and the suggested
next step (usually `/harmonize plan <subsystem>` once the design PR merges).

## Never do

- Write files directly — workers do all writing
- Skip the lock claim
- Leave a lock behind on exit
- Dispatch workers without user approval of the write plan
- Operate outside the claimed `(phase: design, subsystem)`
