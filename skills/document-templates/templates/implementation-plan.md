# {Subsystem Name} Implementation Plan

## Source Documents

```markdown
| Document | Path |
|----------|------|
| Design | [docs/design/{domain}/{group}.md](...) |
| Integration | [docs/design/integration/{a}-{b}.md](...) |
| Test Cases | [docs/design/{domain}/{group}-test-cases.md](...) |
| Features | [docs/features/{domain}/{topic}.md](...) |
| Requirements | [docs/requirements/{domain}/{topic}.md](...) |
```

## Scope

{What is being implemented. Reference specific F-X.Y.Z
feature IDs and R-X.Y.Z requirement IDs from the design.}

### In Scope

- {Feature or capability being implemented}
- {Another feature}

### Out of Scope

- {What is explicitly NOT part of this plan}
- {Deferred to a future plan}

## Crate Structure

```markdown
| Crate | Purpose | Dependencies |
|-------|---------|-------------|
| harmonius_{name} | {purpose} | {deps} |
```

## Task Breakdown

Ordered by implementation sequence. Each task produces
a testable increment.

### Phase 1: Foundation

```markdown
| # | Task | Est | Requirement | Test |
|---|------|-----|-------------|------|
| 1 | {task description} | {hours} | R-X.Y.Z | TC-X.Y.Z.1 |
| 2 | {task description} | {hours} | R-X.Y.Z | TC-X.Y.Z.2 |
```

### Phase 2: Core Features

```markdown
| # | Task | Est | Requirement | Test |
|---|------|-----|-------------|------|
| 3 | {task description} | {hours} | R-X.Y.Z | TC-X.Y.Z.3 |
| 4 | {task description} | {hours} | R-X.Y.Z | TC-X.Y.Z.4 |
```

### Phase 3: Integration

```markdown
| # | Task | Est | Requirement | Test |
|---|------|-----|-------------|------|
| 5 | {integration task} | {hours} | IR-X.Y.Z | TC-X.Y.Z.I1 |
```

### Phase 4: Polish and Optimization

```markdown
| # | Task | Est | Requirement | Test |
|---|------|-----|-------------|------|
| 6 | {optimization task} | {hours} | R-X.Y.Za | TC-X.Y.Z.B1 |
```

## Dependencies

### Blocking (must complete before this plan starts)

- {Design X must be approved}
- {Crate Y must exist}

### Parallel (can proceed alongside)

- {Design Z is independent}

### Downstream (blocked by this plan)

- {Design W depends on types defined here}

## Risk Assessment

```markdown
| Risk | Impact | Mitigation |
|------|--------|------------|
| {risk description} | {H/M/L} | {mitigation strategy} |
```

## Integration Points

For each system this plan touches beyond the primary
design, document the boundary:

```markdown
| System | Data Flow | Phase |
|--------|-----------|-------|
| {other system} | {what data crosses} | {game loop phase} |
```

## Test Strategy

### Unit Tests (Phase 1-2)

- Write failing tests from TC-X.Y.Z entries BEFORE
  implementing
- Each task row maps to specific TC entries
- Run `cargo test` after each task — all new tests green

### Integration Tests (Phase 3)

- Write failing integration tests from TC-X.Y.Z.I entries
- Test cross-system boundaries identified in integration
  design
- Run with real dependencies (no mocking)

### Benchmarks (Phase 4)

- Run benchmarks from TC-X.Y.Z.B entries
- Verify numeric targets from requirements
- Compare against baseline (if exists)

## Verification

How to verify the implementation is complete:

1. All TC-X.Y.Z unit tests pass
2. All TC-X.Y.Z.I integration tests pass
3. All TC-X.Y.Z.B benchmarks meet targets
4. `cargo clippy` — zero warnings
5. `rumdl check .` — zero lint errors on docs
6. Design document updated with any deviations
