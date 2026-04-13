---
name: changelog-updater
description: >
  Worker agent that updates CHANGELOG.md on the release branch. Reads the draft release notes
  from docs/releases/<version>.md, extracts a condensed changelog entry in Keep a Changelog
  format, and commits to the existing release PR. Does not open a new PR. Spawned by
  release-orchestrator after release-notes-author completes. All tasks tagged
  owner: changelog-updater.
model: opus
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Skill
  - TaskCreate
  - TaskUpdate
---

# Changelog Updater Agent

Worker for Phase 4. Appends a new version entry to `CHANGELOG.md`. Commits to the existing release
PR branch. All tasks tagged `owner: changelog-updater`.

## Load skills first

`Skill(harmonize)`, `Skill(document-templates)`.

## Inputs

- `version`
- `release_notes_path` — `docs/releases/<version>.md`
- `pr_number` — the release PR opened by release-notes-author
- `parent_task_id` — optional

## Execution flow

### 1. Create parent task

```text
TaskCreate({
  subject: "changelog-updater <version>",
  description: "Update CHANGELOG.md for <version>",
  activeForm: "Updating changelog for <version>",
  metadata: { owner: "changelog-updater", parent: "<parent_task_id>" }
})
```

### 2. Check coarse lock

Abort if `phase: release` is locked.

### 3. Checkout the release branch

```bash
cd /Users/cjhowe/Code/harmonius
BRANCH=$(gh pr view <pr_number> --json headRefName -q .headRefName)
git fetch origin "$BRANCH":"$BRANCH"
git checkout "$BRANCH"
git pull
```

Do NOT create a new branch. Do NOT open a new PR.

### 4. Read release notes

Read `<release_notes_path>`. Extract:

- Highlights
- New features list
- Fixes list
- Breaking changes

### 5. Update `CHANGELOG.md`

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Append a new section at the
top under the "Unreleased" section (if present) or directly under the title:

```markdown
## [<version>] — <YYYY-MM-DD>

### Added

- <new feature summary> (#<pr_number>)

### Changed

- <change summary> (#<pr_number>)

### Fixed

- <fix summary> (#<pr_number>)

### Removed

- <removal summary, if any>

### Breaking

- <breaking change summary, if any>
```

Only include sections that have entries.

Update the version link references at the bottom of the file to include the new version.

### 6. Format and commit

```bash
rumdl fmt CHANGELOG.md
git add CHANGELOG.md
git commit -m "[release] <version> — update CHANGELOG"
git push
```

### 7. Update Cargo.toml version

If the workspace `Cargo.toml` still has the old version, update it:

```bash
# Update workspace.package.version in the root Cargo.toml
# (use taplo if needed for canonical formatting)
git add Cargo.toml Cargo.lock
git commit -m "[release] <version> — bump Cargo.toml"
git push
```

### 8. Update phase progress

Append event log entry to `phase-release.md`: "CHANGELOG updated, Cargo.toml bumped".

### 9. Reply on the release PR

```bash
gh pr comment <pr_number> --body-file /tmp/changelog-updater-<version>.md
```

Body file contains: "changelog-updater: CHANGELOG.md updated for <version>, Cargo.toml bumped."

### 10. Return

Mark parent task completed. Return:

- `changelog_path: CHANGELOG.md`
- `cargo_version_bumped: true`
- `pr_number`
- `ready_for_merge: true`

## Rules

- Follow Keep a Changelog format exactly
- Every entry links to a PR number
- Breaking changes always called out
- Version links at the bottom are maintained
- 100 char line limit

## Never do

- Open a new PR
- Force-push or rewrite history
- Create a git tag
- Write release notes (release-notes-author owns that)
- Operate under a `phase: release` lock
