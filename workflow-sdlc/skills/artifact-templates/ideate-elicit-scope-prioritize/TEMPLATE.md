---
name: ideate-elicit-scope-prioritize
description: Product-discovery cycle. Four steps — ideate (explore options) → elicit (gather requirements) → scope (cut to what fits) → prioritize (order what remains). Produces a requirements document + a priority-ordered backlog note. Use at the start of a product increment.
contract_version: 1
sdlc_phase: [discover]
inputs:
  - { name: product, type: string, required: true,  description: "Product / area name." }
  - { name: owner,   type: string, required: true }
outputs:
  - { name: requirements, type: artifact_uri }
  - { name: backlog,      type: artifact_uri }
graph:
  steps:
    - id: ideate
      agent: worker
      workflow: write-review
      inputs: { subject: triage-note, owner: "{{ owner }}" }
    - id: elicit
      agent: worker
      workflow: write-review
      inputs: { subject: user-story, owner: "{{ owner }}" }
    - id: scope
      agent: worker
      workflow: write-review
      inputs: { subject: requirement, owner: "{{ owner }}" }
    - id: prioritize
      agent: worker
      prompt_variant: author
      template: implementation-plan
      description: "Produce a priority-ordered backlog note."
  transitions:
    - { id: t1, from: ideate,   to: elicit }
    - { id: t2, from: elicit,   to: scope }
    - { id: t3, from: scope,    to: prioritize }
---

# ideate-elicit-scope-prioritize

Product-discovery loop. Composes write-review at each step so every output is reviewed before the
next step starts.
