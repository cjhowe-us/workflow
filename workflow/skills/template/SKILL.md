---
name: template
description: This skill should be used when the user types `/template` or asks to "create a workflow", "author a template", "edit a workflow", "update a template", "review a workflow", "delete a template", "show a workflow", "list templates", "publish a workflow to workspace", "move a workflow to user scope", or mentions writing or editing workflow files. Exposes sub-commands for create / review / update / delete / move / list / show across override/workspace/user scopes. Artifact templates are workflows too (a subkind) and are handled here.
---

# template

The `/template` entry point covers authoring operations on workflows and artifact templates (both of
which are workflows — artifact templates are the subkind that generate artifacts). Never writes
under any plugin root; always targets override / workspace / user scope.

## Sub-command shape

| Pattern                                        | What to do                                     |
|------------------------------------------------|-------------------------------------------------|
| "create a workflow [called X]"                 | Run `author` meta-workflow with `kind=workflow`|
| "create a template [called X]"                 | Run `author` meta-workflow with `kind=artifact-template` |
| "review <workflow-or-template>"                | Run `review` meta-workflow                      |
| "update <workflow-or-template>"                | Run `update` meta-workflow                      |
| "delete <name>"                                | Remove file at resolved scope (never plugin)   |
| "move <name> --to <scope>"                     | Relocate between override/workspace/user       |
| "list" / "list templates" / "list workflows"   | Read registry; filter by kind                  |
| "show <name>"                                  | Print the file's frontmatter + body            |

## Authoring flow

Author / review / update all delegate to the `authoring` logic loaded from
`references/authoring.md`. At a high level each flow:

1. **draft** — collect the candidate (new) or load the target (existing).
2. **review** — run `workflow-conformance.sh`; surface errors inline.
3. **write** — target a path in override/workspace/user scope; refuse any path under a plugin root.

## References

Load as needed:

- `references/authoring.md` — shared CRUD plumbing, scope resolution, validation steps, refusal
  rules.
- `references/composition.md` — how one workflow references another as a sub-workflow step,
  input/output mapping, artifact-template composition patterns.

## Related skills

- `/workflow` — run a workflow / manage executions.
- `/artifact` — inspect artifacts produced by workflows.
