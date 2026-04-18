---
name: scope-execute-evaluate
description: Project-management cycle. Three steps — scope (define the slice) → execute (deliver it via design-implement-review) → evaluate (measure, retro, decide next). Produces a requirements doc, a delivered change, and a retro note.
contract_version: 1
sdlc_phase: [plan, implement, retro]
inputs:
  - { name: project,     type: string, required: true }
  - { name: target_repo, type: string, required: true }
  - { name: owner,       type: string, required: true }
outputs:
  - { name: scope,    type: artifact_uri }
  - { name: change,   type: artifact_uri }
  - { name: evaluate, type: artifact_uri }
graph:
  steps:
    - id: scope
      agent: worker
      workflow: write-review
      inputs: { subject: requirement, owner: "{{ owner }}" }
    - id: execute
      agent: worker
      workflow: design-implement-review
      inputs: { scope: "{{ project }}", target_repo: "{{ target_repo }}", owner: "{{ owner }}" }
    - id: evaluate
      agent: worker
      workflow: write-review
      inputs: { subject: review-note, owner: "{{ owner }}", context: "{{ steps.execute.outputs.change }}" }
  transitions:
    - { id: t1, from: scope,   to: execute }
    - { id: t2, from: execute, to: evaluate }
---

# scope-execute-evaluate

Project-management-shaped cycle. Evaluate step produces a retro/review note rather than a raw code
review.
