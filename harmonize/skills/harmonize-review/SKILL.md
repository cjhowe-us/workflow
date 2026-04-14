---
name: harmonize-review
description: >
  Interactive Phase 3 (Review) sub-skill for the harmonize SDLC. Loads when the user wants
  to review a draft PR interactively. Claims a coarse interactive lock on (phase=review,
  subsystem), stops the in-flight pr-reviewer for that PR, walks the user through the
  review findings one at a time, then spawns pr-reviewer to address each finding as a
  background task. The user never edits files directly. Used when the user invokes
  /harmonize review, mentions reviewing a PR, or is loaded from the main harmonize skill.
---

# Harmonize — Review (Interactive)

Interactive foreground path for Phase 3 review. The user decides what findings to address;
`pr-reviewer` handles the fix commits.

## When to use

- User says "review PR #<n>" or "check that ECS PR"
- User wants to triage review findings before dispatching fixes
- User wants to approve/reject individual findings
- Loaded by `harmonize` skill when routing a review request

## Load skills first

- `harmonize` — state files, lock protocol
- `document-templates` — plan-progress

## Inputs

Via skill args:

- `pr_url` (optional)
- `pr_number` (optional)
- `plan_id` (optional) — the plan this PR implements

If missing, ask via `AskUserQuestion`.

## Execution flow

### 1. Create a main-level task

```text
TaskCreate({
  subject: "interactive review: PR #<pr_number>",
  description: "User-driven Phase 3 PR review",
  activeForm: "Reviewing PR #<pr_number>",
  metadata: { owner: "main", skill: "harmonize-review" }
})
```

### 2. Load PR and plan state

- `gh pr view <pr_number> --json state,title,body,headRefName,files,comments`
- Resolve `plan_id` and `subsystem` from the PR title (`[impl] PLAN-<id>`) or user input
- Read `docs/plans/<subsystem>/<topic>.md` and `docs/plans/progress/<plan_id>.md`

Verify the PR is in draft state and the plan progress is `code_complete`.

### 3. Check and claim the coarse lock

Lock is `(phase: review, subsystem)`.

Claim protocol:

1. Read `docs/plans/in-flight.md`
2. For every in-flight entry with `worker_agent: pr-reviewer` and matching `subsystem`, call
   `TaskStop(task_id)`
3. Remove those entries
4. Append lock entry to `locks.md`
5. `rumdl fmt`, commit, push

### 4. Dispatch review-supervisor in foreground helper mode

Spawn the existing `review-supervisor` agent to run the three reviewers (correctness, standards,
architecture) against the PR. Because this is interactive, pass a prompt instructing it to return
structured findings without auto-dispatching fixes:

```text
Agent({
  description: "review-supervisor for PR #<pr_number>",
  subagent_type: "review-supervisor",
  prompt: "review PR #<pr_number>, return structured findings, do not dispatch fixes",
  run_in_background: true
})
```

Append to `in-flight.md`.

### 5. Wait for findings

When `review-supervisor` completes:

1. `TaskOutput(task_id)` → read findings
2. Categorize by severity (blocker / major / minor / nit)
3. Remove the in-flight entry

### 6. Triage with the user

For each blocker and major finding, ask via `AskUserQuestion`:

- `address` — dispatch `pr-reviewer` to fix this finding
- `dismiss` — acknowledge but do not fix (rare)
- `escalate` — escalate to design phase (the issue is deeper than the PR)

Minor and nit findings are usually addressed in bulk unless the user opts out.

### 7. Dispatch pr-reviewer with the approved fix list

```text
Agent({
  description: "pr-reviewer fix for PR #<pr_number>",
  subagent_type: "pr-reviewer",
  prompt: "<pr_number, approved_findings, plan_path, progress_path>",
  run_in_background: true
})
```

`pr-reviewer` will commit fixes to the existing PR branch and then undraft the PR.

### 8. Wait for completion

On completion, show the user:

- Fixes committed
- Undraft status
- New PR state (`submitted`)
- Next step: human merges on GitHub

### 9. Release the lock

1. Remove `(phase: review, subsystem)` from `locks.md`
2. `rumdl fmt`, commit, push
3. Dispatch harmonize master agent in background to resume

### 10. Summarize

Report: PR URL, findings count by severity, fixes committed, undrafted status. Complete the main
task.

## Never do

- Commit fixes directly — pr-reviewer owns fix commits
- Merge the PR — humans merge
- Undraft the PR yourself — pr-reviewer handles that
- Skip the lock claim
- Leave a lock behind
- Operate outside the claimed `(phase: review, subsystem)`
