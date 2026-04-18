---
name: design-implement-review
description: Three-step cycle composing write-review (design) → plan-do (implement) → write-review (review). Suitable for non-trivial change that benefits from explicit design before coding and explicit review after. Produces a design document, an implementation PR, and a review note.
contract_version: 1
sdlc_phase: [design, implement, verify]
inputs:
  - { name: scope,       type: string,        required: true,  description: "One-line scope description (goes into titles)." }
  - { name: target_repo, type: string,        required: true }
  - { name: owner,       type: string,        required: true }
outputs:
  - { name: design,      type: artifact_uri, description: "Design document." }
  - { name: change,      type: artifact_uri, description: "Implementation PR." }
  - { name: review,      type: artifact_uri, description: "Review note." }
graph:
  steps:
    - id: design
      agent: worker
      workflow: write-review
      inputs: { subject: design-document, owner: "{{ owner }}" }
      description: "Compose write-review with subject=design-document."
    - id: implement
      agent: worker
      workflow: plan-do
      inputs: { subject: "{{ scope }}", target_repo: "{{ target_repo }}", owner: "{{ owner }}" }
      description: "Compose plan-do for the implementation."
    - id: review
      agent: worker
      workflow: write-review
      inputs: { subject: review-note, owner: "{{ owner }}", context: "{{ steps.implement.outputs.change }}" }
      description: "Compose write-review for verification."
  transitions:
    - { id: t1, from: design,    to: implement }
    - { id: t2, from: implement, to: review }
    - { id: t3, from: review,    to: implement, metadata: { reasoning: "Review requested changes", conditional: "llm-judge" } }
dynamic_branches:
  - step: review
    judge: llm-judge
    transitions: [t3]
---

# design-implement-review

The standard engineering loop — design, implement, review — expressed as a composition of simpler
templates.
