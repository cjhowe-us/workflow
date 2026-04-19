# cjhowe-us/workflow — Claude Code Marketplace

Claude Code plugin marketplace. The `workflow` family replaces the old `coordinator` plugin with a
generic workflow-orchestration system built on two primitives (workflow + artifact) plus swappable
artifact providers.

## Plugins

| Plugin | Purpose |
|--------|---------|
| [`workflow-plugin`](./workflow-plugin) | Generic workflow orchestration plugin. One routing skill `/workflow`, one agent role `worker`, five core artifact providers (`execution`, `file-local`, `conversation`, `preferences`, `notifications`), and meta-workflows for authoring/reviewing/updating workflows. |
| [`workflow-github`](./workflow-github) | GitHub artifact providers: `gh-pr`, `gh-issue`, `gh-release`, `gh-milestone`, `gh-tag`, `gh-branch`, `gh-gist`. Required for GitHub-backed teams. |
| [`workflow-documents`](./workflow-documents) | Document artifact providers (`document` local delegator, `confluence-page`) + eight markdown templates (design, plan, review, release, test, requirement, user-story, triage). |
| [`workflow-sdlc`](./workflow-sdlc) | SDLC artifact templates (write-review, plan-do, design-implement-review, sdlc, PM + project-mgmt + orchestrator cycles) and canned workflows (bug-fix, cut-release). |
| [`rumdl`](./rumdl) | Markdown LSP + PostToolUse formatter hook + `markdown` coding-standard skill. |
| [`env-setup`](./env-setup) | Cross-platform user-env-var onboarding helper (zsh / bash / fish / sh / ksh / PowerShell). Persist `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` cross-platform. |

## Install

```bash
# Add the marketplace (once)
claude plugin marketplace add cjhowe-us/workflow

# env-setup first (workflow expects CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
claude plugin install env-setup@cjhowe-us-workflow

# Core workflow plugin
claude plugin install workflow@cjhowe-us-workflow

# Recommended extensions
claude plugin install workflow-github@cjhowe-us-workflow
claude plugin install workflow-documents@cjhowe-us-workflow
claude plugin install workflow-sdlc@cjhowe-us-workflow

# Optional: rumdl for Markdown linting/formatting
claude plugin install rumdl@cjhowe-us-workflow
```

## Prerequisites

- `workflow` requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — persist it via `env-setup`:
  `/env-setup:env-setup CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 1`.
- `gh` CLI authenticated (`gh auth login`). Identity comes from `gh auth status`; no login dialog.
- `workflow-github` uses only `gh` + `git` internally.
- `workflow-documents`'s `confluence-page` provider needs `CONFLUENCE_BASE_URL`, `CONFLUENCE_USER`,
  `CONFLUENCE_TOKEN`.

## First run

```text
/workflow
```

On first invocation the `default` orchestrator runs a brief tutor walking through the two
primitives, installed extensions, and a guided try-it. Subsequent invocations skip to the dashboard.

## Design

See [`workflow-plugin/DESIGN.md`](./workflow-plugin/DESIGN.md) for the full design document + dated
architecture-decision changelog.

## License

Apache-2.0
