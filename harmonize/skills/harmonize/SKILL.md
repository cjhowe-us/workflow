---
name: harmonize
description: >
  Full SDLC orchestration for Harmonius. Entry point for every stage of the software
  development lifecycle: feature/requirement/user-story ideation, hierarchical design, design
  review, implementation planning, hierarchical TDD execution, PR review, and release.
  Requires plans to link to design docs and design docs to trace F/R/US; progress files link to plans.
  Default run restarts in-flight background tasks before the dispatch wave.
  A bare /harmonize immediately executes the harmonize master orchestrator inline in the current
  conversation (no subagent, no approval, no "what next?" prompt). The orchestrator chains the
  **unblock workflow** (**`unblock-workflow-gh`** via `plan-orchestrator` +
  **`post-merge-dispatch`**) before fanning out every unblocked worker in parallel. Phase
  orchestrators and workers still run as background tasks. Use whenever the user wants to plan,
  design, implement, review, release, or check status of anything in Harmonius, or whenever
  "harmonize" is mentioned. After killed background task trees, `/harmonize reset-in-flight`
  clears stale `in-flight.md` rows before the next `run`; hosts without `TaskList`/`TaskStop`
  flush the registry during restart sweep.
---

# Harmonize

Master entry point for the Harmonius software development lifecycle. Coordinates all four SDLC
phases across hundreds of subsystems. When invoked, the orchestrator runs **inline** in the current
conversation — it is non-interactive and executes the full `agents/harmonize.md` playbook directly.
Phase orchestrators and workers are dispatched as background tasks. Progress is tracked via state
files, hierarchical task lists, and many small GitHub PRs so human review stays readable.

## Execution model

The harmonize master orchestrator runs **inline** in the current conversation — not as a
background subagent. It reads state, reconciles in-flight work, and dispatches phase orchestrators
and workers as background tasks. This means `/harmonize` is **non-interactive**: no approval
gates, no questions, no waiting for user input. The orchestrator executes the full
`agents/harmonize.md` playbook directly, then returns a summary.

Phase orchestrators and workers still run as background `Task` calls with
`run_in_background: true`. State persists to files, so the user can step away and come back.

## Cursor IDE hosts

Cursor does not provide **`Agent(subagent_type: harmonize|plan-orchestrator|…)`**, **`Skill()`**,
**`TaskCreate`**, **`TaskList`**, **`TaskGet`**, **`TaskStop`**, **`TaskOutput`**, or
**`CronList`** / **`CronCreate`**. Use the mapping in **`docs/cursor-host.md`** (plugin repo:
`harmonize/docs/cursor-host.md`; dev checkout **`~/Code/workflow/harmonize`**).

### `run` / bare `/harmonize` on Cursor

1. **`Read`** this skill if the host has no **`Skill`** tool (already satisfied when this file is
   loaded).
2. Execute **`agents/harmonize.md`** **inline** in the current conversation — the full playbook
   runs directly (stash gate → state read → reconcile → unblock gh → dispatch orchestrators).
3. Phase orchestrators and workers are dispatched via **`Task`** with
   **`run_in_background: true`** and **`subagent_type`** per **`docs/cursor-host.md`**.

## Non-negotiable: default `/harmonize` (run) behavior

When the user invokes **`/harmonize`** with **no** arguments, or **`/harmonize run`**, the handler
**must** start work **immediately** — this is the core product behavior.

1. **No approval gate** — do **not** ask which plan or subsystem to prioritize, do **not** wait
   for the user to confirm a "go" after printing status. `/harmonize` is non-interactive.
2. **Inline execution** — execute the `agents/harmonize.md` playbook **directly** in the current
   conversation. Do **not** dispatch the master orchestrator as a background `Task` or `Agent`.
   Phase orchestrators and workers are still dispatched as background tasks.
3. **Ordered gh pass, then parallel unblock** — **`plan-orchestrator`** **`unblock-workflow-gh`** must
   finish (`gh` on every `PLAN-*` with a PR) **before** any implementer dispatch wave. The
   orchestrator chains `post-merge-dispatch` so PR state is reconciled before the dispatch wave.
   Never skip PR reconciliation before that wave in `mode: run`.
4. **Default restart of in-flight work** — on **`run`**, **`post-merge-dispatch`** (after merge
   completes), **`dispatch-only`**, and **`resume`**, the orchestrator performs a **restart sweep** on
   `in-flight.md` (**`unblock-workflow-gh`** is awaited **before** this sweep):
   - If **`TaskList` / `TaskStop` are available**: reconcile rows, then **`TaskStop`** every task
     still listed as running; then spawn **fresh** orchestrators.
   - If those APIs are **absent** (typical Cursor hosts): treat the file as **stale** after a killed
     tree — **flush** `in_flight` to `[]` only (no phase rollup bump for an empty flush), then spawn
     **fresh** orchestrators (never assume dead `task_id` values are still stoppable).
**`status`**, **`unblock-workflow-gh`**, and **`merge-detection`** (legacy alias) do not stop running tasks;
**`stop`** stops them without redispatch.

Use **`/harmonize status`** (or `status` argument) only when the user wants a read-only summary with
**no** background dispatch.

## Nested parallelism (maximum breadth)

Orchestrators should build **deep trees** of **`Agent` / `Task`** calls with **`run_in_background: true`**: one
branch per unblocked plan (and per specify/design worker), not sequential "one plan at a time"
scheduling. **Forbidden** for pacing: `bash sleep` or long idle loops in orchestrators — use task
APIs, completion notifications, or the next harmonize reconciliation pass (`in-flight.md` §3). A
full **`run`** also **stops** stale runners via §3 restart sweep before issuing a new wave.

## Stash gate (clean `main`, material changes only)

Before **`run`**, **`unblock-workflow`**, **`unblock-workflow-gh`**, **`merge-detection`** (alias),
**`dispatch-only`**, or **`resume`**, the harmonize master
(and **`plan-orchestrator`** in those modes) runs this **first** — before **`Skill(harmonize)`**
reload, **`TaskCreate`**, cron, reads of dispatch state, or worker dispatch. It requires:

- `HEAD` on **`main`**
- **Material** porcelain empty in the primary Harmonius checkout — use pathspec exclusions so
  harmonize **progress, state, and tracking** files do **not** count as dirty:

```bash
git -C "$REPO" status --porcelain -- . \
  ':(exclude)docs/plans/progress' \
  ':(exclude)docs/plans/in-flight.md' \
  ':(exclude)docs/plans/worktree-state.json' \
  ':(exclude)docs/plans/harmonize-run-lock.md' \
  ':(exclude)docs/plans/locks.md' \
  ':(exclude)docs/plans/index.md'
```

(Equivalent: `harmonize` plugin **`hooks/material-porcelain.sh`** with **`$REPO`**.)

**Excluded (never trip the gate):** per-phase and **`PLAN-*`** progress under
**`docs/plans/progress/`**, **`in-flight.md`**, **`worktree-state.json`**,
**`harmonize-run-lock.md`**, **`locks.md`**, **`index.md`**. **Not excluded:** implementation plans
**`docs/plans/<subsystem>/...`**, source, specs, and all paths outside those exclusions —
uncommitted edits there still block **`run`**.

**`REPO` for this gate** must be that **primary** tree (**`dirname`** of **`git-common-dir`**), not
the current linked worktree path — otherwise **`HEAD`** and dirty state reflect a worker branch and
the gate **false-fails**. Orchestrator playbooks resolve **`REPO`** accordingly; see
**`plan-orchestrator`** **Resolve `REPO`**.

**`SubagentStart` / `SubagentStop`:** updating **`worktree-state.json`** is best-effort; a failed
replace (e.g. editor lock) must **not** abort the subagent — hooks exit successfully after cleanup.

**Cursor IDE hooks:** on **every** **`subagentStop`**, **`subagent-stop-unblock-workflow.sh`** updates
**`docs/plans/.cursor-hook-unblock-pending.json`** and may submit **`followup_message`** for **`mode:
unblock-workflow`** when no duplicate supervisor task is already in flight (debounced by default **90s**
via **`HARMONIZE_UNBLOCK_HOOK_DEBOUNCE_SEC`**). See **`docs/cursor-host.md`** (Task recovery hooks).

If **material** dirty, **stop** — no orchestrator dispatch. The user runs
**`git stash push -u -m "harmonize-gate"`** (or commits). **No auto-stash.** **`status`**,
**`stop`**, and **`post-merge-dispatch`** skip this gate (continuation after merge reconciliation).

## Killed agent trees (`in-flight.md` orphans)

Stopping nested background tasks in the IDE (or dropping a session) can leave
**`docs/plans/in-flight.md`** rows whose **`task_id` values are dead**. Without
**`TaskList` / `TaskStop`**, the host cannot tell live tasks from ghosts, so the registry may block
locks or duplicate dispatch.

| Situation | Handler action |
|-----------|----------------|
| User killed tasks / restarted worktrees | Run **`/harmonize reset-in-flight`** (synonym: **`clear-in-flight`**) before the next **`run`**. |
| **`reset-in-flight` / `clear-in-flight`** | Set `in_flight: []` only. **No** stash gate; **no** background dispatch; **no** phase rollup churn unless you are also recording a **material** incident. |
| **`mode: run` restart sweep** | With task APIs: follow **`in-flight.md` §Reconciliation loop**. Without them: **flush** + log, then continue (same net effect as a manual reset). |
| Sub-skill **stop-before-lock** | If **`TaskStop`** is missing, **remove** matching rows (or **flush**) instead of waiting on ghosts. |

## Worktree isolation

Git keeps **one** object database per repository; **one primary working tree** (the checkout that
owns the real **`.git`** directory) plus **linked worktrees** (each with its own directory and
**`HEAD`**, sharing that DB). That layout is a **hierarchy for coordination**: the primary tree is
the root for **`docs/plans/`** and **`worktree-state.json`**; linked directories are **child**
checkouts (see **`git worktree list`** — first row is usually the primary tree).

All **specify**, **design**, and **plan TDD** PR branches are created via **`git worktree add`**
under **`$REPO/../harmonius-worktrees/`** (sibling of the primary checkout) so agents never
**`git checkout -b`** inside the primary repo. The primary checkout stays on **`main`** for
coordination.

**No idle worktrees:** Run **`git worktree add`** only when a worker will **change tracked files**
(or add new ones) for a real PR. Do **not** add worktrees for **`unblock-workflow-gh`** / **`merge-detection`** (alias),
**`mode: status`**, read-only reconciliation, empty orchestrator waves, or any pass that will
**not** produce commits. **Orchestrators** (including **`plan-orchestrator`**) **never** run
**`git worktree add`** themselves — only workers that start document or implementation PRs do, at
the moment work begins.

**Subagents are isolated per worktree:** each **`plan-implementer`** owns **one** directory; nested
**`test-writer`** / **`implementer`** runs use that same path — they do not add parallel worktrees
for the same branch. **`SubagentStart`** records **`worktree_path`**, **`worktree_hierarchy`**
(`root` vs `linked` from the Git dir path), **`parent_agent_id`** when the hook supplies it, and
**`tree_path`** (subagent path built from parent rows in **`running_tasks`**).

**Resume:** use **`git worktree list`**, **`PLAN-*`** (`branch`, `worktree_path`, `status`), and
**`locks.md`**. Each lock row names a **branch**, **worktree path**, **phase**, **subsystem**, and a
**one-line `reason`** — together they summarize who owns which checkout; background work skips on
**conflict** (same subsystem+phase, same branch, or same `plan_id` when set).

## `/harmonize-*` sub-skills (interactive)

The master **`harmonize`** skill is the default **autonomous** entry. Each **`/harmonize-<phase>`**
command loads a **foreground** sub-skill for guided work; those skills **claim worktree locks** and
may use `AskUserQuestion`. Route by argument per the table in
[Routing on invocation](#routing-on-invocation).

| Slash / skill | Role |
|---------------|------|
| `harmonize-specify` | Interactive F / R / US authoring |
| `harmonize-design` | Interactive design docs |
| `harmonize-plan` | Interactive implementation plan authoring |
| `harmonize-implement` | Interactive **Phase 3** TDD (`plan-implementer` with user pacing); use when the user wants step-by-step control. **`/harmonize run`** still auto-dispatches **`plan-implementer`** in the background for ready plans without loading this sub-skill |
| `harmonize-review` | Interactive draft PR review |
| `harmonize-release` | Interactive release (explicit user request only) |

When routing **`implement`**, call `Skill(harmonize-implement, <plan_id>)` so the implement playbook
owns locks and pacing.

## The user never edits directly

Interactive sub-skills use `AskUserQuestion` to collect user input. Sub-skills then either:

1. Spawn a background task to do the writing (preferred for any non-trivial file change), or
2. Write files themselves — but only when the change is tiny and the user has approved

The user ONLY provides feedback and decisions. All file writes, git operations, and GitHub PR
actions flow through agents. This keeps every change traceable to a specific agent task, a specific
PR, and a specific review cycle.

## Lifecycle phases

| # | Phase | Orchestrator agent | Workers |
|---|-------|--------------------|---------|
| 1 | Specify | `specify-orchestrator` | `feature-author`, `requirement-author`, `user-story-author` |
| 2 | Design | `design-orchestrator` | `subsystem-designer`, `interface-designer`, `component-designer`, `integration-designer`, `design-reviewer`, `design-reviser` |
| 3 | Plan + TDD + review | `plan-orchestrator` | `plan-author`, `plan-implementer`, `pr-reviewer` |
| 4 | Release | `release-orchestrator` | `release-notes-author`, `changelog-updater`, `tagger` |

Phase 3 is a nested pipeline (plan → TDD → review → merge → dependents) driven by the existing
`plan-orchestrator`.

## Traceability (Specify → Design → Plan)

Every **design** and **plan** must stay linked **upstream**. Orphan artifacts block review and
implementation.

| Downstream | Must link to (upstream) |
|------------|-------------------------|
| Design doc under `docs/design/` | **Features** (`F-X.Y.Z`), **requirements** (`R-X.Y.Z`), and **user stories** (`US-X.Y.Z`) — typically the Requirements Trace table at the top of the doc, or the same IDs repeated in front matter where templates allow. Integration designs cite the F/R/US that justify the cross-subsystem boundary. |
| Implementation plan under `docs/plans/` | One or more **design document paths** in plan front matter (`design_documents`). Those designs must already trace to F/R/US as above. The plan's **`features`**, **`requirements`**, and **`test_cases`** fields must be **consistent** with the linked design docs (no IDs that do not appear in the trace chain). |

**Orchestrator / worker expectations:**

- Phase2 authors treat missing or empty F/R/US trace as **blocking** — do not hand off to plan
  authoring until resolved.
- **`plan-author`** rejects or revises plans with empty `design_documents`, broken paths, or F/R/US
  lists that do not match the cited designs.
- **`plan-implementer`** already aborts when `design_documents` is empty — keep that invariant.

**Forbidden:** plans with no design linkage, designs with no specify linkage, or mismatched ID sets
between plan front matter and the linked design docs.

## Progress and plan links

Rollups and per-plan progress must stay **bidirectionally navigable**:

| File | Must link to |
|------|--------------|
| `docs/plans/progress/PLAN-<id>.md` | Its implementation plan `docs/plans/<subsystem>/<topic>.md`, **`phase-plan.md`**, and **`index.md`** (see `plan-progress` template). |
| `docs/plans/<subsystem>/<topic>.md` (implementation plan) | **`../progress/PLAN-<id>.md`**, **`phase-plan.md`**, **`index.md`** (see `implementation-plan` template). |
| `docs/plans/progress/phase-plan.md` | **Plans** column: each active subsystem lists markdown link(s) to every tracked implementation plan file (and may cite matching `PLAN-*.md`). |

Other phase rollups (`phase-specify.md`, …) use **`—`** in the **Plans** column per template.

## Sub-skills per phase

Each interactive sub-skill claims a **worktree lock** in **`locks.md`** so background workers stay
away from that checkout and scope.

| Sub-skill | For | Typical `phase` on lock |
|-----------|-----|-------------------------|
| `harmonize-specify` | Features, requirements, user stories | `specify` |
| `harmonize-design` | Subsystem, interface, component, integration designs | `design` |
| `harmonize-plan` | Implementation plans | `plan` |
| `harmonize-implement` | Active plan TDD execution | `plan` |
| `harmonize-review` | Draft PR review | `review` |
| `harmonize-release` | Release process | `release` |

## Worktree locks (`docs/plans/locks.md`)

Each row is **one checkout's claim**: **`branch`**, **`worktree_path`** (from `git worktree list`),
**`phase`**, **`subsystem`**, optional **`plan_id`**, **`owner`**, **`claimed_at`**, and a
**short `reason`** line stating what that worktree is doing.

**Together, all rows describe overall hold state** (interactive or manual) — not every background
task. Resume abandoned work from **`git worktree list`** + **`PLAN-*`**, then consult locks for
conflicts.

### Subsystems

Subsystem identifiers match `docs/design/<subsystem>/` names: `ai`, `animation`, `audio`,
`content-pipeline`, `core-runtime`, `data-systems`, `game-framework`, `geometry`, `input`,
`integration`, `networking`, `physics`, `platform`, `rendering`, `simulation`, `tools`, `ui`, `vfx`.

### Stale locks

Stale if **>24h** with no matching activity. Harmonize reports them; it does not auto-clear.

## Hierarchical task lists

All tasks live in the single shared `TaskCreate` list, but every task is tagged with an `owner` so
the list can be filtered by level.

| Owner | Source |
|-------|--------|
| `main` | User-facing session tasks (interactive sub-skills) |
| `harmonize` | Master orchestrator steps |
| `specify-orchestrator` | Phase 1 coordination |
| `design-orchestrator` | Phase 2 coordination |
| `plan-orchestrator` | Phase 3 coordination |
| `release-orchestrator` | Phase 4 coordination |
| `feature-author`, `subsystem-designer`, `plan-implementer`, ... | Fine-grained worker steps |

Filter with `TaskList` then inspect the `owner` field. Each worker creates a parent task for its
invocation and intermediary tasks for each step (read inputs, check lock, open PR, draft file, run
lint, push, update progress).

## Per-phase progress files

| File | Tracks |
|------|--------|
| `docs/plans/progress/phase-specify.md` | Per-subsystem F/R/US counts + PRs |
| `docs/plans/progress/phase-design.md` | Per-subsystem design doc + review status + PRs |
| `docs/plans/progress/phase-plan.md` | Per-subsystem plan-authoring + execution rollup + PRs |
| `docs/plans/progress/phase-release.md` | Release history + current release PR |
| `docs/plans/progress/PLAN-<id>.md` | Per-plan detail (Phase 3) — links to plan file + `phase-plan.md` |

Phase orchestrators update phase-progress files **only when something material changes** (artifacts,
PRs, counts). **`phase-plan.md`** subsystem rows must keep **Plans** links current when plans move
(see [Progress and plan links](#progress-and-plan-links)).

## Many small PRs per phase

Every worker agent opens at least one draft GitHub PR at the start of its work. This makes every
change reviewable on GitHub in small chunks, independent of whether the user is interacting
foreground or the orchestrator is running background.

| Phase | Worker | PR title convention |
|-------|--------|---------------------|
| Specify | feature/requirement/user-story-author | `[specify] <subsystem>:<topic>` |
| Design | subsystem-designer, etc. | `[design] <subsystem>:<topic>` |
| Plan | plan-author | `[plan] <subsystem>:<topic>` |
| TDD | plan-implementer | `[impl] PLAN-<id>` |
| Release | release-notes-author, changelog-updater | `[release] <version>` |

A worker may open multiple PRs if its work decomposes into independent chunks. The pr-reviewer does
not open PRs; it commits review fixes to an existing PR.

## State files

| File | Purpose | Writer |
|------|---------|--------|
| `docs/plans/index.md` | Root plan — total topological order | plan-author, plan-orchestrator |
| `docs/plans/<subsystem>/<topic>.md` | Individual plan files | plan-author |
| `docs/plans/progress/phase-{specify,design,plan,release}.md` | Phase rollups | Phase orchestrators |
| `docs/plans/progress/PLAN-<id>.md` | Per-plan detail | plan-implementer, pr-reviewer |
| `docs/plans/locks.md` | Worktree claims (`branch`, path, phase, subsystem, reason) | Sub-skills (claim/release), harmonize agent (report only) |
| `docs/plans/harmonize-run-lock.md` | One root harmonize chain at a time; live/ambiguous contention → **`AskUserQuestion`** (agent §0b) | harmonize master |
| `docs/plans/in-flight.md` | Running background tasks | harmonize agent, phase orchestrators |
| `docs/plans/worktree-state.json` | **`running_tasks`** ( **`agent_id`**, **`tree_path`**, **`worktree_path`**, **`worktree_hierarchy`**, optional **`parent_agent_id`**, …) + **`last_subagent_*`**; Claude **`SubagentStart`** / **`SubagentStop`** (`bash` + **`jq`**) | plugin hooks only |

## Routing on invocation

When the user invokes this skill, parse the argument and route:

| Argument | Response |
|----------|----------|
| (none) | Same as `run` — continue incomplete work in topological order (see below) |
| `status` | Print SDLC status summary, do not dispatch |
| `run` | Execute the `harmonize` master orchestrator inline for a full SDLC pass |
| `stop` | Stop all in-flight tasks, report, do not release locks |
| `cron` | Bootstrap the unblock-workflow cron |
| `unblock` | Same as **`unblock-workflow`** |
| `unblock-workflow` | Execute orchestrator inline: full unblock (gh on `PLAN-*` + **`post-merge-dispatch`**); **no** root in-flight flush — use after **`SubagentStop`** or when PRs unblock without a full `run` |
| `merge-detect` | Execute orchestrator inline in **`unblock-workflow-gh`** only (legacy name; gh-only, no post-merge dispatch) |
| `merge-detection` | Same as **`merge-detect`** — legacy alias for **`unblock-workflow-gh`** |
| `clear-in-flight` | Same as **`reset-in-flight`** |
| `reset-in-flight` | Clear `docs/plans/in-flight.md` to `[]`; **no** dispatch; **no** stash gate; avoid extra rollup noise |
| `resume <phase> <subsystem>` | After a sub-skill releases a lock, re-dispatch for that resource |
| `specify [topic]` | `Skill(harmonize-specify, <topic>)` |
| `design [doc-path]` | `Skill(harmonize-design, <doc-path>)` |
| `plan [plan-id]` | `Skill(harmonize-plan, <plan-id>)` |
| `implement [plan-id]` | `Skill(harmonize-implement, <plan-id>)` |
| `review [pr-url]` | `Skill(harmonize-review, <pr-url>)` |
| `release [version]` | `Skill(harmonize-release, <version>)` |

Always announce "Loading harmonize-X..." before calling a sub-skill so the user sees the context
switch.

### Default: topological continuation

A bare `/harmonize` (no argument) must **not** stop at status-only or gh-only alone. Execute
the `harmonize` master orchestrator inline with default mode `run` so it:

1. Reconciles **`in-flight.md`** per the
   **[Killed agent trees](#killed-agent-trees-in-flightmd-orphans)** restart sweep (`TaskStop` when
   task APIs exist; **flush** when they do not), enforces locks, re-reads phase + `PLAN-*` files.
2. Runs **`plan-orchestrator`** **`unblock-workflow-gh`** (as a background `Task`) and chains
   **`post-merge-dispatch`** so PR state is reconciled **before** implementers — for each
   `PLAN-*` with a PR, **`gh pr view`**; archive merged plans; update event logs; refresh
   `docs/plans/index.md` when the orchestrator recomputes order — **no** worker dispatch in
   **`unblock-workflow-gh`**.
3. After merge reconciliation, runs the same **restart sweep** on other runners, then re-reads
   progress and computes each phase's ready set.
4. Dispatches **every** phase orchestrator that has ready work **in one parallel batch** (same
   message, multiple `Agent` calls): **`plan-orchestrator`** **`dispatch-only`** plus
   **`specify-orchestrator`** / **`design-orchestrator`** when applicable. **Per-topic** ordering
   stays **Specify → Design → Plan → TDD**; **across subsystems**, work runs **concurrently**.
5. Within Phase 3, **`plan-orchestrator`** fans out **every** ready **`plan-implementer`** /
   **`pr-reviewer`** in parallel (`run_in_background: true`); **dependency order** in
   `docs/plans/index.md` stays enforced by the ready set.

The orchestrator returns the full summary when the pass completes.

## Cron bootstrap

The orchestrator performs cron bootstrap on every `mode: run` pass (see agent playbook).

- **`/harmonize cron`** — may call `CronList` / `CronCreate` directly for manual setup.
- **`status`** — optional read-only cron note only if already known from context.

Cron parameters (for the master agent or `cron` argument):

| Parameter | Value |
|-----------|-------|
| `cron` | `7,22,37,52 * * * *` |
| `recurring` | `true` |
| `durable` | `true` |
| `prompt` | `[harmonize-merge-detect] /harmonize run` |

The cron fires every 15 minutes on off-minutes; Claude receives the prompt, the CLAUDE.md rule maps
`/harmonize` to this skill, and the skill routes to `run` mode which executes the harmonize master
orchestrator inline.

If `CronList` or `CronCreate` is unavailable in the master agent, it logs and continues —
**ordered** unblock gh pass (§5 of the master playbook) still runs that pass before any dispatch.

## Manual unblock workflow

Purpose: run the **full** unblock chain (same §5 as **`run`**, but **without** the root **`run`**
in-flight flush): **`plan-orchestrator`** **`unblock-workflow-gh`**, then **`harmonize`**
**`post-merge-dispatch`** so reviews, ready implementers, and other orchestrators catch up after PRs
unblock — without **`TaskStop`**-ing the whole tree at the start.

### When to run

- User says **`/harmonize unblock-workflow`**, **`/harmonize unblock`**, or the Cursor **`subagentStop`**
  hook suggested it
- After merges or CI clears externally and you want continuation **without** a full **`run`**
  restart sweep

#### How to run

Execute the `agents/harmonize.md` playbook inline with `mode: unblock-workflow`. The orchestrator
performs the same §5 chain (gh on `PLAN-*` + post-merge dispatch).

This pass is idempotent: repeating it should not advance status twice for the same merge.

## Manual gh-only backup (`merge-detect` / `merge-detection`)

Purpose: detect merged Phase 3 PRs (`gh`), advance `PLAN-*` progress — same subset as **`mode:
unblock-workflow-gh`** on the orchestrator (**no** automatic post-merge dispatch).

### When to run

- User says `/harmonize merge-detect` or `/harmonize merge-detection`
- Cron bootstrap in the previous section did not confirm an active `[harmonize-merge-detect]` job
  and a **lightweight** gh check is needed without dispatch

#### How to run

Execute the `agents/harmonize.md` playbook inline with `mode: unblock-workflow-gh`.

This pass is idempotent: repeating it should not advance status twice for the same merge.

## Completion notifications

When background phase orchestrators or workers complete, their output is available via task output
files. State files are the authoritative channel for progress across the orchestration tree.

## SDLC status format

```text
harmonize status — 2026-04-13T16:00:00Z

Phase 1 Specify:     159 / 281 features, 161 / 281 reqs, 161 / 281 stories (3 PRs open)
Phase 2 Design:      281 authored, 12 in review, 0 revising (5 PRs open)
Phase 3 Plan + TDD:  42 total, 7 merged, 2 submitted, 3 code_complete, 5 started
                     25 not_started, 18 blocked by deps
Phase 4 Release:     last 0.1.0 on 2026-03-15, no release in progress

Worktree locks (see docs/plans/locks.md):
  - main @ /path/to/repo — plan:core-runtime — Interactive plan session
  - plan/windowing @ /path/to/wt — plan:platform — Manual hold on PLAN-platform-windowing

git worktree list: (paste or summarize rows)

In-flight background tasks (sparse): 8
  - feature-author (ai, task abc123, started 14:30Z)
  - plan-implementer (PLAN-platform-windowing, task def456, started 14:45Z)

worktree-state.json: running_tasks (agent_id, tree_path, worktree_hierarchy root|linked,
worktree_path, …); last_subagent_start / last_subagent_stop

Cron: active, next fire in 7 minutes
```

## Replaces

| Legacy | Replaced by |
|--------|-------------|
| `workflow` skill | this skill |
| `workflow-supervisor` agent | `harmonize` master agent |
| `ideate` skill | `specify-orchestrator` + `harmonize-specify` + workers |
| `coding-supervisor` agent | `plan-implementer` (already existed) |
| `release-supervisor` agent | `release-orchestrator` |
| `document-author` agent | Phase-specific authors (feature-author, subsystem-designer, plan-author, ...) |

## When to use this skill

- At the start of any Harmonius work session — to check status
- When the user mentions "harmonize" in any form
- When the unblock-workflow cron fires
- When the user wants to author, revise, implement, review, or release anything
- After killing background harmonize tasks — **`/harmonize reset-in-flight`**, then **`/harmonize`**

## When NOT to use this skill

- Isolated code edits unrelated to SDLC flow
- Questions about specific code behavior — use Read/Grep directly
- Git operations outside harmonize plan execution
