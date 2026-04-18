---
name: sdlc
description: Full software-development-lifecycle cycle. Composes write-review (spec) → design-implement-review → docs → cut-release. Produces every canonical SDLC artifact (spec, design, plan, PR, review, docs, release notes, tag). Use at project scope for a clean end-to-end run.
contract_version: 1
sdlc_phase: [spec, design, implement, verify, docs, release]
inputs:
  - { name: project,     type: string,       required: true,  description: "Project / feature name." }
  - { name: target_repo, type: string,       required: true }
  - { name: owner,       type: string,       required: true }
outputs:
  - { name: spec,        type: artifact_uri }
  - { name: change,      type: artifact_uri }
  - { name: docs,        type: artifact_uri }
  - { name: release,     type: artifact_uri }
graph:
  steps:
    - id: spec
      agent: worker
      workflow: write-review
      inputs: { subject: requirement, owner: "{{ owner }}" }
    - id: build
      agent: worker
      workflow: design-implement-review
      inputs: { scope: "{{ project }}", target_repo: "{{ target_repo }}", owner: "{{ owner }}" }
    - id: docs
      agent: worker
      workflow: write-review
      inputs: { subject: release-note, owner: "{{ owner }}", context: "{{ steps.build.outputs.change }}" }
    - id: release
      agent: worker
      workflow: cut-release
      inputs: { target_repo: "{{ target_repo }}", owner: "{{ owner }}" }
  transitions:
    - { id: t1, from: spec,  to: build }
    - { id: t2, from: build, to: docs }
    - { id: t3, from: docs,  to: release }
---

# sdlc

Full SDLC from spec to release. Composition of smaller templates; no new behavior beyond wiring.
