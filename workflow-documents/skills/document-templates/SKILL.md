---
name: document-templates
description: This skill should be used when the user asks to write a "design document", "design doc", "implementation plan", "review note", "release note", "release notes", "test plan", "requirement", "user story", or "triage note", or when a workflow step declares `template: <one of those names>`. Bundles eight fill-in markdown templates the worker uses as starting shells; fills the `{{ placeholder }}` fields from user input and writes via the configured document provider.
---

# document-templates

One skill, eight fill-in markdown shells. Each shell lives under `templates/<name>.md`; a matching
parameter manifest lives under `manifests/<name>.json` (required inputs, output path, produced
kind).

## Bundled templates

| Template               | Purpose                                   | Default output path                       |
|------------------------|-------------------------------------------|--------------------------------------------|
| `design-document`      | Subsystem / feature design                | `docs/design/{{ slug(title) }}.md`         |
| `implementation-plan`  | Task breakdown for a planned change       | `docs/plans/{{ slug(title) }}.md`          |
| `review-note`          | Review findings + verdict                 | `docs/reviews/{{ slug(subject) }}-review.md` |
| `release-note`         | User-facing release summary               | `docs/releases/{{ version }}.md`           |
| `test-plan`            | Strategy + cases + oracles                | `docs/test-plans/{{ slug(title) }}.md`     |
| `requirement`          | Goal + acceptance criteria                | `docs/requirements/{{ id }}.md`            |
| `user-story`           | As-a / I-want-to / So-that                | `docs/user-stories/{{ id }}.md`            |
| `triage-note`          | Observed / hypothesis / next-check        | `docs/triage/{{ slug(title) }}.md`         |

## Workflow

Invoke when a workflow step declares `template: <name>` or when a user asks plainly for one of the
document types.

1. Load the matching manifest from `manifests/<name>.json`. Read its `parameters` list to identify
   required inputs.
2. Collect missing required inputs via `AskUserQuestion`.
3. Read the shell from `templates/<name>.md`. Expand `{{ placeholder }}` fields with the collected
   values; resolve `{{ slug(X) }}` calls to kebab-case.
4. Resolve the target path from the manifest's `output_path` template.
5. Write via the `document` artifact provider: `run-provider.sh document "" create --data -` with a
   payload that includes `path` and `content`.
6. Return the resulting artifact URI for the calling workflow step.

## Placeholder syntax

Templates use `{{ name }}` for plain substitutions and `{{ slug(name) }}` for a kebab-case
conversion of the named field. Anything unresolved at write time fails the step with a validation
error — never ship a document with unresolved `{{ … }}` in it.

## Progressive disclosure

Each template is an asset — not loaded until the worker invokes this skill for a specific kind.
Loading the SKILL.md is enough to see what's available; individual `template.md` reads happen on
demand.

## Customizing

Copy a template to workspace scope at `$REPO/.claude/document-templates/templates/<name>.md` (or to
user / override) to shadow the plugin's version. The plugin's shell is never edited in place — copy,
then edit.
