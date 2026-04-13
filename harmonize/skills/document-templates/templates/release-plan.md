# {Version} Release Plan

## Release Overview

- **Version:** {X.Y.Z}
- **Codename:** {optional}
- **Target date:** {YYYY-MM-DD}
- **Release type:** {Major / Minor / Patch / Hotfix}

## Scope

### Features Included

```markdown
| Feature | Design | Status |
|---------|--------|--------|
| F-X.Y.Z | [design.md](...) | Implemented |
| F-X.Y.Z | [design.md](...) | Implemented |
```

### Features Deferred

```markdown
| Feature | Reason | Target Release |
|---------|--------|---------------|
| F-X.Y.Z | {reason} | {next version} |
```

## Quality Gates

All gates must pass before release:

```markdown
| Gate | Status | Notes |
|------|--------|-------|
| All unit tests pass | {pass/fail} | `cargo test` |
| All integration tests pass | {pass/fail} | |
| All benchmarks meet targets | {pass/fail} | |
| No P0/P1 bugs open | {pass/fail} | |
| Design docs updated | {pass/fail} | |
| API docs generated | {pass/fail} | |
| CHANGELOG.md updated | {pass/fail} | |
| Preview feedback addressed | {pass/fail} | |
| Performance regression check | {pass/fail} | |
| Platform smoke tests | {pass/fail} | |
```

## Platform Testing Matrix

```markdown
| Platform | Build | Unit | Integration | Manual | Status |
|----------|-------|------|-------------|--------|--------|
| Windows | {pass} | {pass} | {pass} | {pass} | {ready} |
| macOS | {pass} | {pass} | {pass} | {pass} | {ready} |
| Linux | {pass} | {pass} | {pass} | {pass} | {ready} |
| iOS | {pass} | {pass} | {n/a} | {pass} | {ready} |
| Android | {pass} | {pass} | {n/a} | {pass} | {ready} |
```

## Migration Guide

### Breaking Changes

1. {Description of breaking change}
   - **Before:** {old behavior}
   - **After:** {new behavior}
   - **Migration:** {steps to update}

### Deprecations

1. {What is deprecated}
   - **Replacement:** {what to use instead}
   - **Removal target:** {version}

## Rollout Strategy

```markdown
| Phase | Action | Duration |
|-------|--------|----------|
| 1 | Internal dogfood | {N days} |
| 2 | Preview to beta users | {N days} |
| 3 | Staged rollout (10%) | {N days} |
| 4 | Full rollout (100%) | {date} |
```

## Rollback Plan

- **Trigger:** {conditions that trigger rollback}
- **Process:** {steps to rollback}
- **Data migration:** {any data considerations}
- **Communication:** {how to notify users}

## Post-Release

- Monitor metrics for {N hours/days}
- Address hotfix items within {N hours}
- Retrospective scheduled for {date}
- Begin next release planning on {date}

## Known Issues

```markdown
| Issue | Severity | Workaround | Fix Target |
|-------|----------|-----------|------------|
| {description} | {P0-P3} | {workaround} | {version} |
```

## Changelog Draft

### Added

- {new feature description}

### Changed

- {changed behavior description}

### Fixed

- {bug fix description}

### Removed

- {removed feature description}
