---
name: author
description: Meta-workflow — create a new workflow or artifact template. Interactive draft → review → write loop, backed by the `authoring` skill and the `file-local` artifact provider. Writes only to override/workspace/user scope; plugin scope is blocked by the `pretooluse-no-self-edit.sh` hook. Use when the user says "create a workflow", "new template", "scaffold a workflow called X".
contract_version: 1
sdlc_phase: [author]
inputs:
  - name: kind
    type: string
    required: true
    description: "workflow | artifact-template"
  - name: name
    type: string
    required: false
    description: "Target name (kebab-case). Prompted if absent."
  - name: scope
    type: string
    required: false
    default: user
    description: "override | workspace | user"
outputs:
  - name: path
    type: artifact_uri
    description: "file-local:<relative-path> of the created file."
graph:
  steps:
    - id: draft
      agent: worker
      prompt_variant: author
      description: "Collect metadata (name, description, inputs/outputs, graph shape) via AskUserQuestion. Produce a candidate file content."
    - id: review
      agent: worker
      prompt_variant: reviewer
      gate: { type: review, prompt: "Approve the draft or request changes?" }
      description: "Show the candidate, run workflow-conformance.sh, let the user request edits."
    - id: write
      agent: worker
      prompt_variant: author
      description: "Resolve target path via the authoring skill. Write via file-local provider. Re-run conformance on the committed file."
  transitions:
    - { id: t1, from: draft,  to: review }
    - { id: t2, from: review, to: write }
    - { id: t3, from: review, to: draft, metadata: { reasoning: "Reviewer requested changes", conditional: "llm-judge" } }
dynamic_branches:
  - step: review
    judge: llm-judge
    transitions: [t2, t3]
---

# author

Three-step template→fill→review cycle that produces a new workflow file or an artifact template
file. Delegates file resolution and validation to the `authoring` skill; uses the `file-local`
artifact provider for writes.

## Step details

### draft

- Prompt the user for: `name`, `description`, SDLC phase tags, inputs, outputs, step graph.
- Generate a candidate markdown+frontmatter file against the `workflow-contract` (or the
  artifact-template shape when `kind` is `artifact-template`).
- Save the draft as a local file under the session's scratch area; the next step reads it from
  there.

### review

- Render the draft.
- Run `tests/workflow-conformance.sh <draft-path>`. If it fails, surface errors inline and loop back
  to `draft` automatically (no user gate needed for validation failures).
- On validation pass, fire the review gate. The user either approves (transition `t2`) or requests
  changes (transition `t3` back to draft).
- An LLM judge at this step proposes the transition based on the validation result + review
  response; confidence below the threshold falls back to the user gate.

### write

- Resolve target path: `authoring.resolve_path(kind, name, scope)`.
- Refuse if path is under a plugin root (double-enforced by hook).
- Write via `file-local.create`.
- Run conformance one more time on the committed path.
- Return `file-local:<relative-path>` as the workflow's output.
