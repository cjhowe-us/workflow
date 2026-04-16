#!/usr/bin/env bash
# Resolve a PR number + branch for a worker assignment. Creates a new draft PR
# on a fresh branch when --pr is not supplied. PRs are the only unit of work in
# the coordinator model — there is no separate issue to link; PR title + body
# carry the work description and the phase label.
#
# Usage:
#   ensure-pr.sh --repo <owner/name> --pr <M> [--project <PVT_...>]
#       Returns metadata for an existing PR. If --project is given, idempotently
#       adds the PR to the project.
#
#   ensure-pr.sh --repo <owner/name> --title "..." --phase specify|design|plan|implement|release|docs \
#       [--branch <name>] [--base <default-branch>] [--body "..."] [--project <PVT_...>]
#       Creates a new draft PR. Branch defaults to `coordinator/<phase>-<slug>`.
#       If --project is given, adds the newly-created PR to the project so the
#       orchestrator sees it on the next dispatch pass.
#
# Emits: { "pr_number": N, "branch": "...", "phase": "...", "created_pr": bool,
#          "project_item_id": "..." | null }
set -euo pipefail

REPO=""; PR=""; TITLE=""; PHASE=""; BRANCH=""; BASE=""; BODY=""; PROJECT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="$2";    shift 2;;
    --pr)      PR="$2";      shift 2;;
    --title)   TITLE="$2";   shift 2;;
    --phase)   PHASE="$2";   shift 2;;
    --branch)  BRANCH="$2";  shift 2;;
    --base)    BASE="$2";    shift 2;;
    --body)    BODY="$2";    shift 2;;
    --project) PROJECT="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[[ -n "$REPO" ]] || { echo "--repo required" >&2; exit 2; }

# Add a PR (by node ID) to a Project v2; idempotent. Emits the resulting item
# node ID on stdout (empty string on failure).
add_pr_to_project() {
  local project_id="$1" pr_number="$2"
  local pr_node_id
  pr_node_id=$(gh pr view "$pr_number" --repo "$REPO" --json id -q '.id' 2>/dev/null || true)
  [[ -z "$pr_node_id" ]] && { echo ""; return; }
  gh api graphql -f query='
    mutation($project: ID!, $pr: ID!) {
      addProjectV2ItemById(input: {projectId: $project, contentId: $pr}) {
        item { id }
      }
    }
  ' -f project="$project_id" -f pr="$pr_node_id" 2>/dev/null \
    | jq -r '.data.addProjectV2ItemById.item.id // ""'
}

# Existing PR — echo metadata and return.
if [[ -n "$PR" ]]; then
  resp=$(gh pr view "$PR" --repo "$REPO" --json number,headRefName,isDraft,labels -q '.')
  br=$(echo "$resp" | jq -r '.headRefName')
  phase=$(echo "$resp" | jq -r '[.labels[].name | select(startswith("phase:"))][0] // ""' | sed 's/^phase://')
  item_id=""
  [[ -n "$PROJECT" ]] && item_id=$(add_pr_to_project "$PROJECT" "$PR")
  jq -n --arg pr "$PR" --arg br "$br" --arg phase "$phase" --arg item_id "$item_id" \
    '{ pr_number: ($pr|tonumber), branch: $br, phase: $phase, created_pr: false,
       project_item_id: (if $item_id == "" then null else $item_id end) }'
  exit 0
fi

# New PR — title + phase are required.
[[ -n "$TITLE" ]] || { echo "--title required when --pr not given" >&2; exit 2; }
[[ -n "$PHASE" ]] || { echo "--phase required (one of specify|design|plan|implement|release|docs)" >&2; exit 2; }
case "$PHASE" in specify|design|plan|implement|release|docs) ;; *)
  echo "invalid --phase: $PHASE" >&2; exit 2;;
esac

if [[ -z "$BASE" ]]; then
  BASE=$(gh repo view "$REPO" --json defaultBranchRef -q .defaultBranchRef.name)
fi
[[ -n "$BASE" ]] || { echo "could not resolve default branch" >&2; exit 2; }

if [[ -z "$BRANCH" ]]; then
  slug=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40)
  [[ -z "$slug" ]] && slug="work"
  BRANCH="coordinator/${PHASE}-${slug}"
fi

if [[ -z "$BODY" ]]; then
  BODY="Draft PR opened by coordinator for phase \`${PHASE}\`.

This PR is the unit of work for this task. When the phase's artifact (spec,
design doc, plan, code change, or release notes) is complete, the worker will
transition this PR from draft to ready-for-review — that is the signal that
the phase is done."
fi

# Caller is expected to have already pushed $BRANCH. Create the draft PR.
pr_url=$(gh pr create \
  --repo "$REPO" \
  --base "$BASE" \
  --head "$BRANCH" \
  --title "$TITLE" \
  --body  "$BODY" \
  --draft)

pr_num=$(echo "$pr_url" | awk -F/ '{ print $NF }')

# Attach the phase label (created on demand if missing).
gh label create "phase:$PHASE" --repo "$REPO" --color ededed --force >/dev/null 2>&1 || true
gh pr edit "$pr_num" --repo "$REPO" --add-label "phase:$PHASE" >/dev/null

# Optionally add to the Project v2 so the orchestrator sees it on next pass.
item_id=""
[[ -n "$PROJECT" ]] && item_id=$(add_pr_to_project "$PROJECT" "$pr_num")

jq -n --arg pr "$pr_num" --arg br "$BRANCH" --arg phase "$PHASE" --arg item_id "$item_id" \
  '{ pr_number: ($pr|tonumber), branch: $br, phase: $phase, created_pr: true,
     project_item_id: (if $item_id == "" then null else $item_id end) }'
