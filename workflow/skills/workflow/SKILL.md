---
name: workflow
description: This skill should be used when the user types `/workflow` or asks to "run a workflow", "start a workflow", "show my dashboard", "what am I running", "resume an execution", "retry a step", "abort", "tunnel to a worker", "raise my wip limit", or mentions workflow executions in general. Dispatches the configured orchestrator (default `default`) and exposes sub-commands for run/status/resume/retry/skip/abort/release/tunnel/untunnel/limit.
---

# workflow

The `/workflow` entry point. Dispatches the configured orchestrator (the workflow named in
`preferences:user.orchestrator` or `preferences:workspace.orchestrator`; default `default`) and
hands it the user's free-form input.

## Sub-command shape

Map the user's input to one of these patterns before loading details. For anything ambiguous, prompt
once via `AskUserQuestion`.

| Pattern                                     | What to do                                          | Load reference |
|---------------------------------------------|------------------------------------------------------|----------------|
| empty / "status" / "what am I running"      | Render dashboard (queries artifact providers live)  | `references/tracking.md` |
| "run/start <workflow> [...]"                | Dispatch via `workflow-execution` artifact template | `references/running.md` |
| "resume <change>"                            | Re-enter at current step of the named execution     | `references/running.md` |
| "retry <change> <step>"                      | Reset retry count + resume                          | `references/running.md` |
| "skip <change> <step>"                       | Mark step complete-skipped                          | `references/running.md` |
| "abort <change>"                             | Terminal abort via the execution provider           | `references/running.md` |
| "release <change>"                           | Clear assignee lock (manual transfer)               | `references/multi-dev.md` |
| "tunnel <worker>" / "untunnel"               | Open / close direct user↔worker channel             | `references/tunneling.md` |
| "limit <N>" / "raise my wip cap"             | Adjust wip caps in `preferences:user`               | `references/running.md` (WIP section) |

## First run (tutor)

On the first invocation after install, `preferences:user.tutor.completed` is falsy. Route to the
tutor flow: three short screens covering the two primitives (workflow, artifact), installed
extensions, and a guided try-it. Set `tutor.completed = true` on finish.

Re-open later with "teach me again" or equivalent.

## Invariants held here

- No in-repo runtime state.
- Identity from `gh auth status`; no login dialog.
- One orchestrator per machine (flock).
- Progress rendered on demand from provider queries; no caches.
- Plugin files are immutable; writes go to override / workspace / user scope via the `/template`
  skill's meta-workflows.

## References

Load these only when the user's intent matches:

- `references/running.md` — dispatch, WIP caps, retries, blockers, needs- attention, aborts. The
  single biggest reference.
- `references/tracking.md` — how the dashboard renders, what it queries, format of the compact +
  detail views.
- `references/tunneling.md` — tunnel semantics, envelope shapes, force- close behavior.
- `references/multi-dev.md` — identity, presence gist, assignee lock, ownership transfer.
- `references/workflow-contract.md` — workflow file schema (needed when inspecting an execution's
  workflow or explaining its shape).

## Related skills

- `/template` — author, review, update, list artifact templates (which are workflows).
- `/artifact` — inspect artifacts behind any provider (PRs, issues, docs, releases, etc.).
