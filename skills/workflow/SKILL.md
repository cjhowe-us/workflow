---
name: workflow
description: >
  Development lifecycle workflow for the Harmonius project.
  Use this skill when planning work, deciding what phase comes
  next, creating tasks, discussing process, or when the user
  asks about the development workflow, lifecycle stages, TDD
  process, or release process. Also use when determining which
  artifacts to produce at each stage.
---

# Development Workflow

## Lifecycle Phases

The development lifecycle has 4 phases, executed in order. Each phase has internal stages. Feedback
can recurse to earlier phases.

### Phase 1: Specify

Stages: Idea → Ideate → Review

Templates (`document-templates` skill):

- `templates/feature.md` → write feature definitions
- `templates/requirement.md` → write requirements
- `templates/user-story.md` → write user stories

Steps:

- Start with a rough idea for a new capability
- Use the `ideate` skill to expand into F/R/US
- Detect cross-system features → mark for integration
- Human reviews and approves or requests revision
- Revision loops back to Ideate
- Approval advances to Phase 2

### Phase 2: Design

Stages: Design Doc → Design Review

Templates (`document-templates` skill):

- `templates/design-document.md` → subsystem design
- `templates/integration-design.md` → cross-system design
- `templates/test-cases.md` → companion test cases

Steps:

- Create design doc from the design-document template
- If cross-system, also create integration design
- Create companion test cases file
- Use the `document-author` agent for guided authoring
- Design review identifies issues, contradictions, gaps
- Review feedback appended to the design document
- Feedback loops back to revise the design
- Approval advances to Phase 3

### Phase 3: Test-Driven Development

Stages: Plan → Red Unit → Implement → Green Unit → Red Integration → Implement → Green Integration
[→ Red E2E → Implement → Green E2E]

Templates (`document-templates` skill):

- `templates/implementation-plan.md` → task breakdown
- `templates/test-cases.md` → if companion file missing

Steps:

- Create implementation plan from the template
- Write failing unit tests first (red) from requirements and the companion test cases file
- Implement source code to make tests pass (green)
- Write failing integration tests from requirements
- Implement to make integration tests pass
- Optionally: E2E tests from user stories
- All green advances to Phase 4

### Phase 4: Ship

Stages: Manual Test → Debug → Docs → Preview → Feedback → Release → Maintain

Templates (`document-templates` skill):

- `templates/release-plan.md` → release checklist + rollout

Steps:

- Manual testing catches issues automated tests miss
- Debug and fix discovered issues
- Update documentation (API docs, tutorials, guides)
- Preview release for customer feedback
- Customer feedback may recurse to earlier phases
- Approved feedback leads to release
- Maintain with patches and updates

## Recursion

At any point from Phase 3 onward, the process can recurse to an earlier phase when issues are
discovered:

| Trigger | Recurse To | Phase |
|---------|-----------|-------|
| Wrong requirements | Ideate | 1 |
| Architecture issue | Design Doc | 2 |
| Task breakdown wrong | Plan | 3 |
| Missing unit tests | Red Unit | 3 |
| Integration gap | Red Integration | 3 |
| Customer feedback | Ideate, Design, or Plan | 1-3 |
| Maintenance issue | Plan | 3 |

## Stage Details

| Stage | Input | Output | Skill |
|-------|-------|--------|-------|
| Ideate | Rough idea | F/R/US files | `ideate` |
| Design | F/R/US | Design doc + test cases | `document-templates` |
| Design Review | Design doc | Feedback section | Manual |
| Plan | Approved design | Implementation plan | `document-templates` |
| Red Unit | Requirements | Failing tests | TDD |
| Implement | Failing tests | Source code | — |
| Green Unit | Source code | Passing tests | — |
| Red Integration | Requirements | Failing integration | TDD |
| Green Integration | Source code | Passing integration | — |
| Manual Testing | Running build | Bug reports | Manual |
| Documentation | Implemented code | Updated docs | — |
| Preview | Tested build | Preview release | — |
| Feedback | Preview | Feedback items | Manual |
| Release | Approved build | Tag, changelog | `document-templates` |
| Maintain | Released version | Patches | — |

## Artifacts Per Phase

| Phase | Artifacts |
|-------|-----------|
| Specify | docs/features/, docs/requirements/, docs/user-stories/ |
| Design | docs/design/group.md, docs/design/group-test-cases.md |
| Plan | Implementation plan (task breakdown) |
| TDD | src/crate/, tests/unit/, tests/integration/, tests/e2e/ |
| Ship | CHANGELOG.md, git tag, documentation updates |

Artifact dependencies:

- Features + requirements + user stories → inform design doc
- Design test cases → drive unit and integration tests
- User stories → drive E2E tests
- Unit/integration/E2E tests → validate source code
- Source code → changelog → git tag

## Stage-to-Skill Mapping

| Stage | Skill | Template |
|-------|-------|----------|
| Ideate | `ideate` | feature, requirement, user-story |
| Design | `document-templates` | design-document, integration-design |
| Plan | `document-templates` | implementation-plan |
| Tests | `rust` | test-cases |
| Implement | `rust` | — |
| Release | `document-templates` | release-plan |
| Docs | `markdown` | — |
