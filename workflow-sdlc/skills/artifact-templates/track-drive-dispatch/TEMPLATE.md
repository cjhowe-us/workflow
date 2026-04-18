---
name: track-drive-dispatch
description: Orchestrator-shaped meta cycle. Three steps — track (poll active executions + retroactive diff) → drive (surface blockers / gate-pending items / stalls) → dispatch (start or resume work per user intent). Recommended backing for custom orchestrator workflows that want this shape with extra domain logic.
contract_version: 1
sdlc_phase: [orchestrate]
inputs:
  - { name: target_scope, type: string, required: false, default: "all", description: "Scope: all | repo:<owner/repo> | project:<name>" }
outputs:
  - { name: summary, type: string, description: "Rendered dashboard." }
graph:
  steps:
    - id: track
      agent: worker
      prompt_variant: orchestrator
      description: "Query active execution providers; compute retroactive-step diffs; build a state snapshot."
    - id: drive
      agent: worker
      prompt_variant: orchestrator
      description: "Surface blockers, gate-pending items, stalled executions; queue user prompts where needed."
    - id: dispatch
      agent: worker
      prompt_variant: orchestrator
      description: "Honor user requests: start new, resume, tunnel, abort, author."
  transitions:
    - { id: t1, from: track,  to: drive }
    - { id: t2, from: drive,  to: dispatch }
    - { id: t3, from: dispatch, to: track, metadata: { reasoning: "Continue loop after action", conditional: "llm-judge" } }
dynamic_branches:
  - step: dispatch
    judge: llm-judge
    transitions: [t3]
---

# track-drive-dispatch

Use as the base for a custom orchestrator: copy to workspace or user scope, rename (e.g.
`mycorp-orchestrator`), add domain steps around the three core steps, then set it as the
`orchestrator` workspace preference.
