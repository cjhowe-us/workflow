---
name: bug-fix
description: Diagnose, fix, and ship a production bug end-to-end. Three composed steps — triage (write-review:triage-note) → fix (plan-do:fix) → release-note (write-review:release-note). Opens a PR on the target repo, assigns current `gh auth` user, posts progress to PR comments. Use when an issue or PR surfaces a real defect.
contract_version: 1
sdlc_phase: [implement, release]
inputs:
  - { name: source_artifact, type: artifact_uri, required: true,  description: "gh-issue:... or gh-pr:... URI of the reported bug." }
  - { name: target_repo,     type: string,       required: true,  description: "Repo to open the fix PR against, `<owner>/<repo>`." }
  - { name: owner,           type: string,       required: true,  description: "gh auth user taking ownership." }
outputs:
  - { name: fix_pr,      type: artifact_uri, description: "PR with the fix." }
  - { name: release_note, type: artifact_uri, description: "Release note document." }
graph:
  steps:
    - id: triage
      agent: worker
      workflow: write-review
      inputs: { subject: triage-note, owner: "{{ owner }}", context: "{{ inputs.source_artifact }}" }
    - id: fix
      agent: worker
      workflow: plan-do
      inputs: { subject: "bugfix for {{ inputs.source_artifact }}", target_repo: "{{ inputs.target_repo }}", owner: "{{ owner }}" }
    - id: release-note
      agent: worker
      workflow: write-review
      inputs: { subject: release-note, owner: "{{ owner }}", context: "{{ steps.fix.outputs.change }}" }
  transitions:
    - { id: t1, from: triage,      to: fix }
    - { id: t2, from: fix,         to: release-note }
    - { id: t3, from: release-note, to: fix, metadata: { reasoning: "Release-note reviewer wants code revision", conditional: "llm-judge" } }
dynamic_branches:
  - step: release-note
    judge: llm-judge
    transitions: [t3]
---

# bug-fix

End-to-end bug handling. Start with
`/workflow start bug-fix --source gh- issue:owner/repo/42 --target-repo owner/repo`.
