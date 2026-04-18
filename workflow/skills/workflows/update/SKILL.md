---
name: update
description: Meta-workflow — apply edits to an existing workflow or artifact template. Resolves the target via scope precedence (refusing plugin-scope paths), applies the user's edit instructions, validates with workflow-conformance.sh, and writes via file-local. Use when the user says "update the bug-fix workflow", "edit my template", "change X in Y".
contract_version: 1
sdlc_phase: [update]
inputs:
  - name: uri
    type: artifact_uri
    required: true
    description: "file-local:<relative-path> of the target."
  - name: instructions
    type: string
    required: true
    description: "Free-form description of the changes to apply."
outputs:
  - name: uri
    type: artifact_uri
    description: "The same URI; content is updated in place."
graph:
  steps:
    - id: load
      agent: worker
      prompt_variant: reviewer
      description: "Resolve URI; refuse plugin-scope paths; read current content."
    - id: edit
      agent: worker
      prompt_variant: author
      description: "Apply edit instructions; produce candidate content; run workflow-conformance.sh."
    - id: write
      agent: worker
      prompt_variant: author
      gate: { type: review, prompt: "Approve the diff before writing?" }
      description: "Show diff; on approval, write via file-local and re-run conformance."
  transitions:
    - { id: t1, from: load,  to: edit }
    - { id: t2, from: edit,  to: write }
    - { id: t3, from: write, to: edit, metadata: { reasoning: "User requested further changes", conditional: "llm-judge" } }
dynamic_branches:
  - step: write
    judge: llm-judge
    transitions: [t3]
---

# update

Edit an existing workflow or artifact template in place. Enforces the plugin-files-immutable rule at
the load step — a URI that resolves to a plugin root is rejected with a clear error pointing the
user at override scope or an external PR.

## Step details

### load

- Resolve URI via scope precedence (`authoring.resolve_path`).
- If resolved path is under any installed plugin root → refuse with the message: "plugin files are
  immutable; copy to workspace or override scope first, or open a PR to the plugin repo."
- Otherwise, read current content; stash for diff.

### edit

- Apply the user's `instructions` to the current content. For small changes, produce a literal
  rewrite; for large ones, propose a structured edit plan and confirm each piece.
- Run `tests/workflow-conformance.sh` on the candidate. If it fails, surface errors and loop back to
  edit (no user gate for validation failures).

### write

- Show a unified diff of current → candidate.
- Fire the review gate. On approval (`t2` completion), write via `file-local.update`. Re-run
  conformance on the committed file.
- On rejection (dynamic branch `t3`), loop back to edit with the user's change requests.
