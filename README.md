# Workflow Plugin

A Claude Code plugin that provides the complete development
lifecycle for the Harmonius game engine: ideation, design,
test-driven development, code review, and release.

## Install

```bash
# Add the marketplace
claude plugin marketplace add cjhowe-us/workflow

# Install the plugin
claude plugin install workflow@cjhowe-us-workflow --scope project
```

## Update

```bash
claude plugin update workflow@cjhowe-us-workflow --scope project
```

## Uninstall

```bash
claude plugin uninstall workflow --scope project
```

## Skills

| Skill | Purpose |
|-------|---------|
| `workflow` | Development lifecycle phases |
| `ideate` | Generate features, requirements, stories |
| `document-templates` | Templates for all document types |
| `rust` | Rust coding standard |
| `hlsl` | HLSL shader coding standard |
| `markdown` | Markdown documentation standard |
| `json` | JSON configuration standard |
| `toml` | TOML configuration standard |
| `yaml` | YAML workflow standard |

## Agents

| Agent | Role | Model |
|-------|------|-------|
| `workflow-supervisor` | Full lifecycle orchestration | opus |
| `coding-supervisor` | TDD cycle (red-green-refactor) | opus |
| `review-supervisor` | Code review orchestration | opus |
| `release-supervisor` | Release process | opus |
| `document-author` | Guided template filling | opus |
| `test-writer` | Write failing tests from TC entries | opus |
| `implementer` | Implement code to pass tests | opus |
| `correctness-reviewer` | Check code vs design | opus |
| `standards-reviewer` | Check coding standards | opus |
| `architecture-reviewer` | Check engine constraints | opus |

## Templates

| Template | Path |
|----------|------|
| Design document | `skills/document-templates/templates/design-document.md` |
| Integration design | `skills/document-templates/templates/integration-design.md` |
| Implementation plan | `skills/document-templates/templates/implementation-plan.md` |
| Release plan | `skills/document-templates/templates/release-plan.md` |
| Feature | `skills/document-templates/templates/feature.md` |
| Requirement | `skills/document-templates/templates/requirement.md` |
| User story | `skills/document-templates/templates/user-story.md` |
| Test cases | `skills/document-templates/templates/test-cases.md` |

## Lifecycle

```text
Phase 1: Specify  (ideate skill)
Phase 2: Design   (document-templates + document-author)
Phase 3: TDD      (coding-supervisor + test-writer)
Phase 4: Ship     (release-supervisor)
```

Use the `workflow-supervisor` agent to orchestrate all
phases automatically.

## License

Apache-2.0
