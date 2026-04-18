# workflow

Generic workflow orchestration plugin for Claude Code. Two primitives — **workflow** and
**artifact** — plus a uniform artifact-provider contract. One routing skill, `/workflow`, opens the
default orchestrator (which doubles as a first-run tutor) and routes every interaction through it.

## Install

Via the marketplace:

```bash
claude plugin marketplace add cjhowe-us/workflow
claude plugin install workflow@cjhowe-us-workflow
claude plugin install workflow-github@cjhowe-us-workflow      # optional: GH providers
claude plugin install workflow-documents@cjhowe-us-workflow   # optional: doc templates
claude plugin install workflow-sdlc@cjhowe-us-workflow        # optional: SDLC cycles
```

The core `workflow` plugin runs alone; `workflow-github`, `workflow-documents`, and `workflow-sdlc`
are recommended extensions.

## Prerequisites

- `gh` CLI, authenticated (`gh auth login`). Identity comes from `gh auth status` — no login dialog.
- `git` ≥ 2.30 (worktrees).
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in the environment. The `env-setup` plugin can persist
  this.

## First run

`/workflow` with no input opens the dashboard. On the very first invocation the `default`
orchestrator runs its tutor: welcome, the two primitives, installed extensions, and a guided try-it.
Subsequent invocations skip straight to the dashboard and intent routing.

## Architecture in one diagram

```text
               ┌─────────────────────────────┐
/workflow ─────►      routing skill         │
               │  (thin; no domain logic)    │
               └─────────────┬───────────────┘
                             │
                             ▼
               ┌─────────────────────────────┐
               │   default (orchestrator)    │
               │  — interprets user intent   │
               │  — loads only what's needed │
               │  — dispatches workers       │
               │  — polls providers          │
               │  — renders dashboard        │
               └──┬──────────────────────┬───┘
                  │                      │
         ┌────────▼──────┐      ┌────────▼──────┐
         │   workers     │◄─────►   providers   │
         │ (teammates)   │ gh   │ (one per kind)│
         └───────────────┘ api  └───────────────┘
                                         │
                                         ▼
                               ┌───────────────────┐
                               │   GitHub / local  │
                               │   filesystem /    │
                               │   Confluence /    │
                               │   Jira / Figma /  │
                               │   Slack / ...     │
                               └───────────────────┘
```

## Two primitives

- **Workflow** — a markdown file with YAML frontmatter describing a runnable DAG of steps. Lives in
  plugin / user / workspace / override scope. Composes via `step.workflow: <name>` for
  sub-workflows.
- **Artifact** — everything else the system reads or writes: GitHub PRs, issues, releases, tags,
  branches, worktrees; Jira tickets; Confluence pages; Figma designs; conversation logs; compiler
  failures; local files. Each artifact kind has a provider that implements `get`, `create`,
  `update`, `list`, `lock`, `status`, `progress`.

A workflow execution is itself an artifact (default provider: the workflow's GitHub PR body +
comments).

## Files

- `agents/worker.md` — the single agent role.
- `hooks/` — session start, PreToolUse, PostToolUse, SubagentStop, TeammateIdle, UserPromptSubmit.
- `scripts/` — `run-provider.sh`, `discover.sh`, `orchestrator-lock.sh`.
- `skills/workflow/` — `/workflow` entry skill; running, dashboard, tunneling, multi-dev, wip.
  References under `references/` load on demand.
- `skills/template/` — `/template` entry skill; authoring and composition of workflows and artifact
  templates.
- `skills/artifact/` — `/artifact` entry skill; inspecting artifacts via providers, discovery
  registry, extension-plugin scaffold.
- `skills/workflows/` — `default`, `author`, `review`, `update` (the meta-workflows the three entry
  skills delegate to).
- `skills/artifact-templates/` — `write-review`, `plan-do`, `workflow-execution`. Primitive
  composable cycles + the canonical dispatch template every run flows through.
- `artifact-providers/` — plain scripts (not skills): `execution`, `file-local`, `conversation`,
  `preferences`, `notifications`. Each ships `manifest.json` + `artifact.sh`.
- `tests/workflow-conformance.sh`, `tests/provider-conformance.sh`.
- `DESIGN.md` — full design doc + dated changelog of architecture decisions.

## Extending

Ship workflows, artifact templates, or artifact providers from a sibling Claude Code plugin; the
core plugin auto-discovers them at session start. The three in-repo extensions — `workflow-github`,
`workflow-documents`, `workflow-sdlc` — are reference implementations. Use
`/artifact add a provider` to generate a starter plugin.

## Not supported

- Writing under any installed plugin's root (blocked by `pretooluse-no-self-edit.sh`). To change a
  built-in workflow, copy it to workspace/user/override scope or open a PR to the plugin repo.
- Automatic transfer of artifact locks. Ownership changes are manual (e.g. reassigning a PR on
  GitHub).
- Preserving v1 `coordinator` data. v2 is a fresh install; re-open any open PRs under the new
  conventions.

## License

Apache-2.0.
