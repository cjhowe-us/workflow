#!/usr/bin/env bash
# Print git porcelain for "material" changes on the primary checkout: everything except
# harmonize coordination files (progress rollups, in-flight registry, locks, index, JSON hooks).
# Usage: material-porcelain.sh <REPO>
# Non-empty stdout => stash gate should fail. Same pathspecs as harmonize skill / agent §0.
set -euo pipefail
REPO="${1:?repository root}"

git -C "$REPO" status --porcelain -- . \
  ':(exclude)docs/plans/progress' \
  ':(exclude)docs/plans/in-flight.md' \
  ':(exclude)docs/plans/worktree-state.json' \
  ':(exclude)docs/plans/harmonize-run-lock.md' \
  ':(exclude)docs/plans/locks.md' \
  ':(exclude)docs/plans/index.md'
