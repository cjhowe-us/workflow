# {Subsystem Name} Design

## Requirements Trace

> **Canonical sources:** Features, requirements, and user
> stories are defined in [features/](../../features/),
> [requirements/](../../requirements/), and
> [user-stories/](../../user-stories/).

```markdown
| Feature | Requirement |
|---------|-------------|
| F-X.Y.Z | R-X.Y.Z     |

1. **F-X.Y.Z** -- Description
```

## Overview

{3-5 sentence summary of what this subsystem does and why.}

Key architectural choices:

1. {Choice 1}
2. {Choice 2}

```markdown
### Interop Contracts Defined Here

| Contract | Consumed By |
|----------|-------------|
| {type/API} | {other designs} |
```

## Architecture

### Module Boundaries

{Mermaid graph showing modules and dependencies}

### File Layout

{Directory tree showing crate structure}

### Core Data Structures

{Mermaid classDiagram covering ALL types: structs, enums
with variants, traits, type aliases, relationships}

## API Design

{Rust pseudocode for all public types and functions.
Group by concern. Include doc comments.}

## Data Flow

{Sequence diagrams and/or flowcharts showing how data
moves through the subsystem.}

## Platform Considerations

```markdown
| Platform | {Column per concern} |
|----------|---------------------|
| Windows  | ...                 |
| macOS    | ...                 |
| Linux    | ...                 |
| iOS      | ...                 |
| Android  | ...                 |
| Switch   | ...                 |
```

```markdown
### Proposed Dependencies

| Crate | Justification |
|-------|---------------|
| {name} | {why needed} |
```

## Safety Invariants

{Document all unsafe code boundaries, safety contracts,
and invariants that must hold.}

## Test Plan

See [{group}-test-cases.md]({group}-test-cases.md) for
the complete test case listing.

```markdown
### Summary

| Category | Coverage |
|----------|----------|
| Unit | {list of areas} |
| Integration | {list of areas} |
| Benchmarks | {list of targets} |
```

## Design Q & A

**Q1. Biggest constraint?** ...

**Q2. How to improve?** ...

**Q3. Better approach?** ...

**Q4. Missing features?** ...

**Q5. Cohesion with engine?** ...

## Open Questions

1. **{Question}** -- {context and options}
