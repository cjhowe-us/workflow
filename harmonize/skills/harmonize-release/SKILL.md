---
name: harmonize-release
description: >
  Interactive Phase 4 (Release) sub-skill for the harmonize SDLC. Loads when the user wants
  to cut a release. Claims the global release lock, stops any in-flight release workers,
  walks the user through release scope questions, then spawns release-notes-author,
  changelog-updater, and tagger as background tasks sequentially to produce the release PR
  and tag. The user never edits files directly. Used when the user invokes /harmonize
  release, mentions cutting a release, or is loaded from the main harmonize skill.
---

# Harmonize — Release (Interactive)

Interactive foreground path for Phase 4. The user decides scope and version; background workers
draft release notes, update the changelog, and create the tag after the human merges the release PR.

## When to use

- User says "let's cut a release" or "release <version>"
- User wants to review what would go into a release before committing
- Loaded by `harmonize` skill when routing a release request

## Load skills first

- `harmonize` — state files, lock protocol, phase-release
- `document-templates` — release-notes and release-plan templates

## Inputs

Via skill args:

- `version` (optional) — target version string
- `scope` (optional) — `patch` / `minor` / `major`

If missing, ask via `AskUserQuestion`.

## Execution flow

### 1. Create a main-level task

```text
TaskCreate({
  subject: "interactive release: <version>",
  description: "User-driven Phase 4 release",
  activeForm: "Releasing <version>",
  metadata: { owner: "main", skill: "harmonize-release" }
})
```

### 2. Compute the current state

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
CURRENT_VERSION=$(grep -E '^version' Cargo.toml | head -1)
```

Gather merged PRs since `LAST_TAG` via `gh pr list`.

### 3. Determine version

If `version` not given, compute a suggestion based on `scope` and current version. Confirm with the
user via `AskUserQuestion`.

### 4. Check and claim the global release lock

Read `docs/plans/locks.md`. Look for `phase: release`.

| State | Action |
|-------|--------|
| No lock | Claim it |
| Held by another session | Ask user to wait or abort |
| Stale (>24h) | Offer to release and reclaim |

#### Claim protocol

1. Read `docs/plans/in-flight.md`
2. Call `TaskStop` on every in-flight entry with `phase: release`
3. Remove entries from `in-flight.md`
4. Append the release lock to `locks.md`:

   ```yaml
   - phase: release
     subsystem: "*"
     claimed_at: <ISO 8601 UTC now>
     owner: harmonize-release
     reason: Releasing <version>
   ```

5. Commit + push the lock change

### 5. Present the release scope

Show the user:

- Last tag: `<LAST_TAG>`
- Target version: `<version>`
- PRs to include: count + categorized list
- Any breaking changes detected (from `[breaking]` labels or `BREAKING:` commit trailers)

### 6. Guided release Q&A

Ask via `AskUserQuestion`:

1. **Highlights** — Which 3-5 changes are the headline items for the release notes?
2. **Upgrade notes** — Any breaking changes users must know about?
3. **Scope confirmation** — Include all listed PRs, or exclude some?
4. **Rollback plan** — How would we roll back if something is wrong?

### 7. Confirm the release plan

Summarize:

- Version
- Release PR that will be opened
- CHANGELOG sections that will be added
- Tag that will be created after merge

Ask for approval via `AskUserQuestion` (yes / edit / cancel).

### 8. Dispatch release-notes-author

```text
Agent({
  description: "release-notes-author <version>",
  subagent_type: "release-notes-author",
  prompt: "<version, pr list, highlights, upgrade notes>",
  run_in_background: true
})
```

Append to `in-flight.md`, commit, push.

### 9. Wait for completion, show user, then dispatch changelog-updater

When release-notes-author completes, read its output, show the draft release notes to the user via
`AskUserQuestion` (approve / revise / cancel). On approve:

```text
Agent({
  description: "changelog-updater <version>",
  subagent_type: "changelog-updater",
  prompt: "<version, release_notes_path, pr_number>",
  run_in_background: true
})
```

Wait for completion.

### 10. Hand over to the human for PR review + merge

Tell the user: "Release PR is ready for your review at <pr_url>. Merge it on GitHub when you are
ready. Then come back here and run `/harmonize release tag <version>` to create the tag."

Keep the lock claimed — do not release it yet. The tag step requires the merge.

### 11. After merge, dispatch tagger

When the user confirms the merge:

```text
Agent({
  description: "tagger <version>",
  subagent_type: "tagger",
  prompt: "<version, release_notes_path, pr_number>",
  run_in_background: true
})
```

Wait for completion.

### 12. Release the lock

1. Remove `phase: release` entry from `locks.md`
2. `rumdl fmt`, commit, push
3. Dispatch harmonize master agent in background to resume other phases

### 13. Summarize

Report: version, tag name, PR URL, notable items. Complete the main task.

## Never do

- Write files directly
- Skip the lock claim
- Create the tag before the release PR is merged
- Dispatch tagger in parallel with release-notes-author or changelog-updater
- Leave a release lock behind on exit
