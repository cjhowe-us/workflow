---
name: cut-release
description: Cut a release. Three steps — changelog (assemble + commit) → release-notes (write-review) → tag (create gh-tag + gh-release). Use when a train of merged PRs is ready to ship. Produces a release note document and published GitHub release.
contract_version: 1
sdlc_phase: [release]
inputs:
  - { name: target_repo,  type: string, required: true,  description: "<owner>/<repo>" }
  - { name: version_hint, type: string, required: false, description: "Suggested semver; the workflow may refine it." }
  - { name: owner,        type: string, required: true }
outputs:
  - { name: release_note, type: artifact_uri }
  - { name: release,      type: artifact_uri }
  - { name: tag,          type: artifact_uri }
graph:
  steps:
    - id: changelog
      agent: worker
      prompt_variant: author
      description: "Assemble changelog entries from merged PRs since the last tag; commit to a release branch."
    - id: release-notes
      agent: worker
      workflow: write-review
      inputs: { subject: release-note, owner: "{{ owner }}" }
    - id: tag
      agent: worker
      prompt_variant: author
      description: "Create gh-tag (release branch HEAD) and gh-release (published, with release-note body)."
  transitions:
    - { id: t1, from: changelog,     to: release-notes }
    - { id: t2, from: release-notes, to: tag }
---

# cut-release

Release cycle. Assumes merges are already in main; this workflow does not merge PRs — it only
assembles the release surface on top of them.
