---
name: ideate
description: >
  Generate features, requirements, and user stories from a new idea.
  Use when the user has an idea for a new engine capability and wants
  to expand it into formal features (F-X.Y.Z), requirements (R-X.Y.Z),
  and user stories (US-X.Y.Z). Trigger when user mentions a new idea,
  wants to add a capability, says "I have an idea for", "let's add",
  "what about adding", or wants to brainstorm new engine features.
  Always use this skill before any design work on new capabilities.
---

# Ideate: Idea to Features, Requirements, and User Stories

Turn a rough idea into formal Harmonius project artifacts. This skill runs before any design work.

```text
Idea → Expand features (human review) → Write features
     → Generate requirements + stories (human review)
     → Write final artifacts
```

## Relationship Model

Features, requirements, and user stories have a **one-to-many** relationship:

- **One feature** → **many requirements** (functional R-X.Y.Z and non-functional R-X.Y.Za suffixed
  variants)
- **One feature** → **many user stories** (different personas, each with 1 action and 1 use case)

Requirements and user stories are independently numerous per feature. A single feature like F-1.1.1
might produce R-1.1.1, R-1.1.1a, and US-1.1.1, US-1.1.2 — all tracing back to that one feature.

## Phase 1: Understand the Idea

Read these files to understand context:

- `docs/features/README.md` — feature index, domain numbering
- `docs/requirements/README.md` — requirements index
- `docs/user-stories/personas.md` — all available personas
- The CLAUDE.md in each doc directory for formatting rules

Identify which **domain** (module number 1-15) and **topic** the idea belongs to. Check existing
files in that domain to find the next available ID numbers.

## Phase 2: Expand the Idea into Features

Break the idea into granular features. For each, consider:

- Core capabilities and variants
- Platform-specific behaviors (mobile, desktop, Switch, VR)
- Dependencies on existing features (use F-X.Y.Z refs)
- Related capabilities users would expect alongside this

Present proposed features to the user as a numbered list with:

- Proposed ID (F-X.Y.Z)
- Short name
- One-sentence description
- Dependencies on existing features

Group under logical subheadings. Suggest 2-3 additional features the user may not have considered —
things that naturally complement the idea or that users of similar game engines would expect.

**Cross-system detection:** For each feature, check whether it touches multiple subsystems. If a
feature requires changes in 2+ design documents, mark it as an integration feature:

- Add `Integration: {System A} ↔ {System B}` to the feature
- Flag it for an integration design document
- Add corresponding integration user stories

Examples: ragdoll (animation ↔ physics), sound occlusion (audio ↔ spatial), particle gameplay (VFX ↔
physics ↔ ECS).

**Use AskUserQuestion** to confirm:

- Which proposed features to keep
- Which suggested expansions to include
- Whether any features are missing
- Which features are cross-system (integration)

## Phase 3: Write Feature Documents

After user confirmation, write features following the format in `docs/features/CLAUDE.md`. Match the
style of existing files like `docs/features/core-runtime/entity-component-system.md`.

Structure per section in a feature file:

```markdown
# X.Y — Topic Name

## Section Name

| ID      | Feature           | Requirements     |
|---------|-------------------|------------------|
| F-X.Y.Z | Feature Name     | R-X.Y.Z, R-X.Y.Za |

1. **F-X.Y.Z** — Description of the capability, how it works at a high level, and what it enables.
   Concrete usage examples help.
   - **Deps:** F-A.B.C (Name), F-D.E.F (Name)
   - **Platform:** Platform-specific notes if applicable
```

The Requirements column in the feature table lists ALL requirement IDs that derive from that feature
(comma-separated).

Key rules:

- Features describe capability, not implementation
- No SHALL statements (those belong in requirements)
- Group related features under section headings
- Summary table at top of each section, detail list below
- Tables must fit within 100 characters per line
- All lines wrap at 100 characters

Write to `docs/features/{domain}/{topic}.md`. If the file exists, append to the appropriate
sections. Update the features README.md index table.

## Phase 4: Generate Requirements and User Stories

For each feature, generate **multiple** requirements and **multiple** user stories.

### Requirements

Each feature should produce:

- **Functional requirements** (R-X.Y.Z) — what the system SHALL do
- **Non-functional requirements** (R-X.Y.Za) — performance bounds, memory limits, scalability
  targets

The suffix convention: R-1.1.1 is the functional requirement, R-1.1.1a is its non-functional
companion. A feature may have more than one non-functional requirement (R-X.Y.Zb, R-X.Y.Zc, etc.) if
distinct performance dimensions apply.

Format per `docs/requirements/CLAUDE.md`:

```markdown
# R-X.Y — Topic Requirements

## Section

| ID       | Derived From                               |
|----------|--------------------------------------------|
| R-X.Y.Z  | [F-X.Y.Z](../../features/domain/topic.md)  |
| R-X.Y.Za | [F-X.Y.Z](../../features/domain/topic.md)  |

1. **R-X.Y.Z** — The engine **SHALL** [testable statement].
   - **Rationale:** Why this requirement matters.
   - **Verification:** How to test/measure compliance.
2. **R-X.Y.Za** — The engine **SHALL** [performance bound].
   - **Rationale:** Why this bound is necessary.
   - **Verification:** Benchmark or measurement approach.
```

Rules:

- **SHALL** for mandatory, **SHOULD** for recommended
- Every requirement must be testable and measurable
- Performance requirements need specific numeric targets
- Multiple requirements from one feature share the base ID but use letter suffixes for
  non-functional variants

### User Stories

Each feature should produce **multiple** user stories from **different personas**. Each story is
granular: 1 persona + 1 action + 1 use case + 1 feature.

Good persona coverage per feature:

- A **game developer** (P-15) or **designer** (P-5) story for the end-user perspective
- An **engine tester** (P-27) story for testability
- A **tool/editor** persona story if the feature has UI
- Additional personas as the feature warrants

Format per `docs/user-stories/CLAUDE.md`:

```markdown
# Topic User Stories

## Section

| ID       | Persona              | Features | Requirements |
|----------|----------------------|----------|--------------|
| US-X.Y.Z | persona name (P-NN) | F-X.Y.Z  | R-X.Y.Z      |

1. **US-X.Y.Z** — [action from persona's perspective], so that [concrete benefit]
   - **Acceptance:** Criterion 1<br>Criterion 2<br> Criterion 3
```

The Requirements column in the user story table references the primary requirement, not necessarily
all of them.

**Use AskUserQuestion** to present the generated requirements and user stories for review. Group by
feature so the user can verify coverage. Ask:

- Are any requirements missing or too vague?
- Are the verification criteria realistic and measurable?
- Are the right personas selected for each user story?
- Are any user stories or perspectives missing?
- Should any features have additional non-functional requirements?

## Phase 5: Write Final Artifacts

After user approval:

1. Write requirements to `docs/requirements/{domain}/{topic}.md`
2. Write user stories to `docs/user-stories/{domain}/{topic}.md`
3. Update the requirements and user stories README.md index tables
4. If a topic file already exists, append new entries to the appropriate sections rather than
   overwriting

## Checklist

- [ ] Feature IDs are unique and follow F-X.Y.Z convention
- [ ] Each feature has multiple requirements (functional + NFR)
- [ ] Each feature has multiple user stories from varied personas
- [ ] Requirement IDs trace back to features (R-X.Y.Z ← F-X.Y.Z)
- [ ] Non-functional requirements use letter suffixes (a, b, c)
- [ ] User story IDs trace back to features (US-X.Y.Z ← F-X.Y.Z)
- [ ] All cross-references use correct relative paths
- [ ] Tables fit within 100 character line width
- [ ] All lines wrap at 100 characters
- [ ] No design details or implementation in feature files
- [ ] No SHALL statements in feature files
- [ ] All requirements are testable with specific criteria
- [ ] User stories are granular (1 persona, 1 action, 1 feature)
- [ ] README index files updated for all three doc directories
- [ ] Run `rumdl fmt .` on all new/modified markdown files

## Templates

Read these template files from the `document-templates` skill when writing artifacts:

| Artifact | Template File |
|----------|--------------|
| Feature | `templates/feature.md` |
| Requirement | `templates/requirement.md` |
| User story | `templates/user-story.md` |

This skill (ideate) handles the PROCESS of generating content. The `document-templates` skill
defines the STRUCTURE. Fenced code blocks in templates are placeholders — remove them and replace
with real data.

## Lifecycle Position

Ideation is the FIRST stage of the `workflow` skill's development lifecycle (Phase 1: Specify).
After ideation:

1. Use the `document-templates` skill to create a design document (read
   `templates/design-document.md`)
2. If cross-system, also create an integration design (read `templates/integration-design.md`)
3. Use the `workflow` skill to track progress through subsequent phases (Design → TDD → Ship)
