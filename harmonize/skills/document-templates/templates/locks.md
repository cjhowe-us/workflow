---
locks: []
---

# Interactive Locks

Active coarse-grained locks on SDLC resources. The harmonize orchestrator reads this file
before dispatching any background work and skips any resource listed here. Sub-skills add
entries when the user engages interactively; they remove entries when the user exits.

## Lock grain

Locks are **coarse**: `(phase, subsystem)` pairs. One lock covers all files in a subsystem for
a given phase, so background workers can still progress on unrelated subsystems or unrelated
phases of the same subsystem.

## Entry schema

```yaml
locks:
  - phase: specify         # specify | design | plan | review | release
    subsystem: ai          # subsystem identifier (e.g., ai, core-runtime, rendering)
    claimed_at: {ISO 8601 UTC timestamp}
    owner: {sub-skill name that claimed the lock}
    reason: {short human-readable reason}
    session_id: {optional Claude session identifier}
```

## Example

```yaml
locks:
  - phase: design
    subsystem: core-runtime
    claimed_at: 2026-04-13T15:00:00Z
    owner: harmonize-design
    reason: User revising ECS archetype API
  - phase: plan
    subsystem: core-runtime
    claimed_at: 2026-04-13T15:30:00Z
    owner: harmonize-plan
    reason: User authoring ECS query plan
```

## Stale locks

A lock older than 24 hours with no matching phase-progress activity is considered stale.
Harmonize reports stale locks to the user and offers to release them; it does not auto-clear
them.
