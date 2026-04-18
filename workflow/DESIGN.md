# workflow plugin — design document

Source of truth for the workflow plugin's architecture. Append-only changelog at the bottom records
material design decisions. Edits to the plan that change these architectural choices must add a
dated changelog entry here too.

## Problem

Claude Code teams need orchestrated, multi-workflow automation that spans product, project, and SDLC
work; coordinates multiple developers without a central server; reports progress through systems
teams already use (PRs, issues, docs); uses pluggable backends behind a stable contract; and keeps
the plugin surface minimal enough that authors compose domain workflows without a new DSL.

## Non-goals

- A task tracker replacing Jira / Linear.
- A workflow DSL richer than sequential/parallel composition plus dynamic branching.
- Preserving v1 coordinator data — v2 is a fresh install.

## Foundational concepts

Precise definitions used throughout. The plugin holds these meanings consistently.

**Two top-level primitives: workflow and artifact.** They are peers, not nested. Workflows are
definitions of executable behavior; artifacts are everything else the system reads or writes. A
workflow can *itself* be treated as an artifact in one narrow case — when it is the output of a
template-driven generation — because artifact generation is itself a template→fill→review workflow.
Outside that context workflows and artifacts stay distinct.

- **Workflow** — the composition primitive. A workflow is a markdown file with YAML frontmatter
  (standard Claude Code skill shape) describing a runnable DAG of steps with typed inputs and
  outputs. Frontmatter carries the declaration inline — no JSON sibling. A step may reference
  another workflow as a sub-workflow (*composition*). Workflows live in plugin, user, workspace, or
  override scope. A workflow is *not* an artifact; it is a recipe for running and producing
  artifacts. The one exception is during template-driven authoring: the `author` workflow generates
  workflow files as its output, and during that generation those output files are treated as
  artifacts by the hosting artifact provider.

- **Artifact template** — a subkind of workflow (not a separate primitive). An artifact template is
  a workflow whose graph is template→fill→review and whose outputs are artifacts. Templates are
  file-type-agnostic (markdown, JSON, YAML, any text), can **reference other templates** (really:
  invoke other template workflows as sub-workflows) for composition, and can
  **generate nested folder trees** or hierarchical structures from dynamic inputs. Kept in
  `artifact-templates/` for catalog clarity, but authored and run exactly like any other workflow.

- **Artifact** — any file, record, or system object the system reads or writes. Artifacts span:
  - **Local files** — markdown, JSON, YAML, workflows, templates, arbitrary text.
  - **External system records** — GitHub PRs, issues, releases, milestones, tags, branches,
    worktrees, gists; Jira tickets; Confluence pages; Figma designs and screenshots; conversation
    logs; runtime logs; compiler/test failures; retroactively imported work items; any surface a
    workflow touches.

**A workflow execution is an artifact.** Execution state is decoupled from the workflow definition —
the workflow is the recipe, the execution is the artifact produced when that recipe runs. The
default `execution` provider backs executions with the workflow's PR description + comments on
GitHub. Artifacts are the *only* runtime state; the plugin never writes runtime state to its own
files or to the repo.

- **Artifact provider** — a small skill that ships one script, `artifact.sh`, with the fixed
  subcommand surface `get`, `create`, `update`, `list`, `lock`, `status`, `progress`. Each provider
  decides how to implement each subcommand for its backend (`gh-pr` via `gh`; `file-local` via the
  filesystem; `execution` typically via PR body + comments). Providers own progress tracking,
  locking semantics, and backend-specific context for their kind.

- **Orchestrator (role, not primitive)** — any worker running the configured orchestrator workflow
  (default: `default`) plays the orchestrator role for that run. No orchestrator object. When
  `/workflow` is invoked, a worker is pointed at the orchestrator workflow; it interprets user
  intent, loads only the files needed, dispatches other workers, polls providers, renders the
  dashboard. Workspace or user preferences may name a different workflow to play the role.

- **Worker** — a teammate agent that executes workflows. One role: `worker`. Workers are reusable: a
  worker **switches between worktrees** as it moves between workflow executions (`cd`-ing to the
  target worktree). At any moment a worktree has at most one active worker; across time a worker may
  visit many. Concurrent executions can use multiple workers in parallel (each on its own worktree)
  when throughput benefits.

- **Composition** — the only reuse mechanism. A step's `workflow:` field references another
  workflow; that sub-workflow runs as the step's body on its own worktree, with its own PR, and with
  inputs the parent supplies explicitly. No inheritance, no overriding, no subclassing. Small
  workflows composed into larger ones.

## Key invariants

1. Two top-level primitives: workflow and artifact.
2. No in-repo runtime state. No `.workflow/` directory. All state lives in artifacts.
3. Artifact providers implement: `get`, `create`, `update`, `list`, `lock`, `status`, `progress` via
   one script per provider.
4. Artifact templates are file-type-agnostic, composable (reference other templates), and can
   generate folder hierarchies dynamically from inputs.
5. At any moment, one worker per worktree. Workers may switch between worktrees over time, but two
   workers are never in the same worktree concurrently.
6. One worktree per execution. Parent and children run in parallel on disjoint worktrees.
7. Children never acquire any lock on parent and cannot write to parent's artifacts unless the
   parent explicitly grants write access.
8. Child PR `base = <parent PR head branch>`. Merges bubble up.
9. Parent detects child completion by polling the child execution's provider `status`.
10. Progress renders on demand by querying provider `progress`. No caches.
11. Multi-developer presence uses a **per-GitHub-user private gist**
    (`workflow-user-lock-<gh-user-id>`) that tracks all currently-active sessions across machines.
    Multiple machines may run sessions for the same user simultaneously; the gist is a presence
    registry, not a mutex. Artifact-level locks (PR assignee, etc.) enforce single-writer per
    artifact.
12. One orchestrator per machine (flock at `$XDG_STATE_HOME/workflow/orchestrator.lock`).
13. Plugin files are immutable to agents. Changes come via override scope or external PR.
14. Only `aborted` is terminal. Failures become `needs_attention`, resolvable by the user without
    losing progress.
15. JSON everywhere except necessary markdown frontmatter (`kind:` + `data:`).
16. `SendMessage` content is **strict JSON, unwrapped and unfenced** — one JSON object as the entire
    message body. No prose, no markdown, no code fence. Receivers parse strictly; malformed input
    fails fast.
17. **Durable workflow state lives on GitHub.** Every piece of state that must survive a session,
    move between machines, or be seen by other developers is stored on GitHub via an artifact
    provider. Ephemeral session state (orchestrator flock, in-session notifications, dispatch
    ledger) is local only. Professional-team portability: a teammate who pulls the repo and runs
    `/workflow` on a fresh machine reconstructs full state from GitHub.
18. **Bidirectional sync + retroactive completion.** Workflow definitions are living; execution
    artifacts are authoritative for what happened. On every scan the engine diffs each execution's
    step ledger against its workflow's current definition; gaps are surfaced as *retroactive steps*
    the user may backfill. External mutations to artifacts (PR edited on github.com, etc.) are
    reconciled on the next scan. No missed migrations.

## Design changelog

Append-only. Every material design change adds a dated row.

| Date       | Decision |
|---|---|
| 2026-04-17 | Initial design: coordinator → generic workflow plugin. |
| 2026-04-17 | One agent role (`worker`); engine is itself a built-in workflow. |
| 2026-04-17 | Composition-only reuse; no inheritance. |
| 2026-04-17 | PR per execution; hierarchical branch / worktree / execution names. |
| 2026-04-17 | Assignee-only lock; global orchestrator flock. |
| 2026-04-17 | LLM judge carries confidence; gate fires below threshold. |
| 2026-04-17 | Parent and children run in parallel; children never lock parent. |
| 2026-04-17 | Plugin files immutable to agents; changes via override scope or external PR. |
| 2026-04-17 | Items → externals; item-adapters → artifact-providers. |
| 2026-04-17 | All runtime state in externals; no `.workflow/` directory. |
| 2026-04-17 | Parent polls child provider for completion; dashboard queries providers on demand. |
| 2026-04-17 | Durable state defaults to GitHub-native storage (PR body, labels, checks, comments, optional gist); ephemeral state stays local. |
| 2026-04-17 | External → workflow artifact (broader concept). Artifacts include local files, external system records, AI conversations, and the workflow execution itself. Artifact providers replace external providers (same contract). |
| 2026-04-17 | Artifact templates added as first-class. File-type-agnostic, composable, support nested folder trees, hierarchical generation from dynamic inputs. |
| 2026-04-18 | Workers are reusable and switch between worktrees (not one-worker-per-worktree-for-life). Worktree-level exclusivity preserved at any moment. |
| 2026-04-18 | Multi-developer presence is a per-GitHub-user private gist tracking active sessions across machines; multi-machine allowed. Artifact-level locks enforce single-writer per artifact. |
| 2026-04-18 | Identity comes from `gh auth status`; no login dialog. Tutor instructs `gh auth login` on first use if unauthenticated. |
| 2026-04-18 | Two primitives (workflow + artifact), peers. Artifact templates are a subkind of workflow. Workflow executions are artifacts (decoupled from the workflow definition). A workflow can itself be an artifact only during template-driven authoring. |
| 2026-04-18 | Workflow definitions are plain markdown with YAML frontmatter (standard skill shape); no md+json sibling. |
| 2026-04-18 | Artifact types expanded: Figma designs, screenshots, conversation logs, runtime logs, compiler/test failures, retroactive items — any external surface is fair game. |
| 2026-04-18 | Orchestrator is a role, not a primitive: a worker running the orchestrator workflow plays the role. |
| 2026-04-18 | Agent role named `worker`. |
| 2026-04-18 | `SendMessage` protocol is strict, unwrapped, unfenced JSON. |
| 2026-04-18 | Extension split: `workflow-github` (PR/issue/release/tag/etc.), `workflow-documents` (doc templates + providers), `workflow-sdlc` (SDLC templates + workflows). |
| 2026-04-18 | Stale child resolution stops the child teammate (SubagentStop) in addition to surfacing the needs_attention notification. |
| 2026-04-18 | Bidirectional sync between workflows and artifacts. Step ledger per execution with step signatures enables retroactive-step detection. External artifact mutations reconciled on next scan. No missed migrations. |
