# workflow-sdlc

SDLC artifact templates and canned workflows for the [`workflow`](../workflow) plugin. Depends on
[`workflow-github`](../workflow-github) for PR/issue/release artifacts and
[`workflow-documents`](../workflow-documents) for document templates.

## Artifact templates (cycles)

Composable; each is a workflow whose outputs are one or more artifacts. `write-review` and `plan-do`
— the two primitive cycles these templates compose — ship in the core `workflow` plugin, not here.

| Template                          | Shape                                                  |
|-----------------------------------|--------------------------------------------------------|
| `design-implement-review`         | design (write-review) → implement (plan-do) → review   |
| `sdlc`                            | spec → design-implement-review → docs → cut-release    |
| `ideate-elicit-scope-prioritize`  | product discovery cycle                                |
| `scope-execute-evaluate`          | project-management cycle                               |
| `track-drive-dispatch`            | orchestrator-shaped meta cycle                         |

## Workflows

| Name          | Purpose                                           |
|---------------|---------------------------------------------------|
| `bug-fix`     | Diagnose, fix, and ship a production bug          |
| `cut-release` | Cut a release (changelog + release notes + tag)   |

## Install

```bash
claude plugin install workflow-github@cjhowe-us-workflow
claude plugin install workflow-documents@cjhowe-us-workflow
claude plugin install workflow-sdlc@cjhowe-us-workflow
```

## Use

```text
/workflow start bug-fix --source gh-issue:owner/repo/42 --target-repo owner/repo
/workflow start cut-release --target-repo owner/repo --version-hint v2.1.0
```

Or compose `design-implement-review` / `sdlc` as sub-workflow steps inside a custom workflow of your
own.

## Custom orchestrator

Copy `track-drive-dispatch` to workspace or user scope, add domain steps, and set
`orchestrator: <your-workflow-name>` in `.claude/workflow.preferences.json`.

## License

Apache-2.0.
