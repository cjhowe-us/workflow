---
name: review
description: Meta-workflow — critique an existing workflow or artifact template without modifying it. Loads the target via the authoring skill, runs conformance + heuristic checks (naming, step-id uniqueness, input/output coverage, dynamic-branch reachability, dead transitions), and emits a report. Never writes. Use when the user says "review the X workflow", "audit my template".
contract_version: 1
sdlc_phase: [review]
inputs:
  - name: uri
    type: artifact_uri
    required: true
    description: "file-local:<relative-path> of the workflow or template to review."
outputs:
  - name: findings
    type: string
    description: "Markdown report of findings + suggestions."
graph:
  steps:
    - id: load
      agent: worker
      prompt_variant: reviewer
      description: "Resolve URI, read file content."
    - id: critique
      agent: worker
      prompt_variant: reviewer
      description: "Run workflow-conformance.sh; apply heuristic checks; generate findings."
    - id: report
      agent: worker
      prompt_variant: reviewer
      description: "Format findings as markdown; present to the user."
  transitions:
    - { id: t1, from: load,     to: critique }
    - { id: t2, from: critique, to: report }
---

# review

Read-only workflow. Loads a workflow/template, runs checks, reports findings. Never mutates the
source file; suggested edits are emitted as prose for the user to apply via `update` (or directly).

## Heuristic checks (in addition to conformance)

- **Naming** — kebab-case, unique within scope, not a reserved name.
- **Step-id uniqueness** — enforced by conformance, but the reviewer also flags near-duplicates that
  may confuse operators.
- **Input/output coverage** — every declared input appears in at least one step's context; every
  declared output is produced by at least one step's artifacts.
- **Dynamic-branch reachability** — every transition listed in a dynamic_branches entry leads to a
  step that will actually run in some execution scenario.
- **Dead transitions** — transitions not reachable from the entry step are flagged; common after a
  refactor.
- **Gate coverage** — steps with no `gate` on dynamic branches are allowed, but the reviewer flags
  the tradeoff (LLM judge runs alone).
- **Retry signal** — workflows with no explicit retry-cap reference fall back to the provider
  default (3); the reviewer surfaces this so the author can decide if the default is appropriate.
