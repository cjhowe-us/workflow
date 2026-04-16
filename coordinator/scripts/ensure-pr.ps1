# Resolve a PR number + branch for a worker assignment. Creates a new draft
# PR on a fresh branch when -Pr is not supplied. PRs are the only unit of
# work in the coordinator model — there is no separate issue to link; the PR
# title + body carry the work description and the phase label.
#
# Usage:
#   pwsh -NoProfile -File ensure-pr.ps1 -Repo <owner/name> -Pr <M> [-Project <PVT_...>]
#       Returns metadata for an existing PR. If -Project is given, idempotently
#       adds the PR to the project.
#
#   pwsh -NoProfile -File ensure-pr.ps1 -Repo <owner/name> -Title "..." `
#       -Phase specify|design|plan|implement|release|docs `
#       [-Branch <name>] [-Base <default-branch>] [-Body "..."] [-Project <PVT_...>]
#       Creates a new draft PR. Branch defaults to coordinator/<phase>-<slug>.
#       If -Project is given, adds the newly-created PR to the project so the
#       orchestrator sees it on the next dispatch pass.
#
# Emits JSON: { "pr_number": N, "branch": "...", "phase": "...", "created_pr": bool,
#               "project_item_id": "..." | null }

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$Repo,
  [int]$Pr,
  [string]$Title,
  [ValidateSet('specify','design','plan','implement','release','docs')]
  [string]$Phase,
  [string]$Branch,
  [string]$Base,
  [string]$Body,
  [string]$Project
)

$ErrorActionPreference = 'Stop'

function Add-PrToProject {
  param([string]$ProjectId, [int]$PrNumber, [string]$RepoName)
  $prNodeId = & gh pr view $PrNumber --repo $RepoName --json id -q '.id' 2>$null
  if (-not $prNodeId) { return '' }
  $q = @'
mutation($project: ID!, $pr: ID!) {
  addProjectV2ItemById(input: {projectId: $project, contentId: $pr}) {
    item { id }
  }
}
'@
  try {
    $resp = & gh api graphql -f "query=$q" -f "project=$ProjectId" -f "pr=$prNodeId" 2>$null |
      ConvertFrom-Json -Depth 20
    return $resp.data.addProjectV2ItemById.item.id
  } catch {
    return ''
  }
}

# Existing PR — echo metadata and return.
if ($PSBoundParameters.ContainsKey('Pr') -and $Pr -gt 0) {
  $resp = & gh pr view $Pr --repo $Repo --json 'number,headRefName,isDraft,labels' -q '.' |
    ConvertFrom-Json
  $existingPhase = ''
  foreach ($l in $resp.labels) {
    if ($l.name -like 'phase:*') { $existingPhase = $l.name.Substring(6); break }
  }
  $itemId = ''
  if ($Project) { $itemId = Add-PrToProject -ProjectId $Project -PrNumber $Pr -RepoName $Repo }
  [ordered]@{
    pr_number       = $Pr
    branch          = $resp.headRefName
    phase           = $existingPhase
    created_pr      = $false
    project_item_id = $(if ($itemId) { $itemId } else { $null })
  } | ConvertTo-Json -Compress
  exit 0
}

if (-not $Title) { Write-Error "-Title required when -Pr not given"; exit 2 }
if (-not $Phase) { Write-Error "-Phase required (specify|design|plan|implement|release|docs)"; exit 2 }

if (-not $Base) {
  $Base = & gh repo view $Repo --json defaultBranchRef -q '.defaultBranchRef.name'
}
if (-not $Base) { Write-Error "could not resolve default branch"; exit 2 }

if (-not $Branch) {
  $slug = ($Title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
  if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).TrimEnd('-') }
  if (-not $slug) { $slug = 'work' }
  $Branch = "coordinator/$Phase-$slug"
}

if (-not $Body) {
  $Body = @"
Draft PR opened by coordinator for phase ``$Phase``.

This PR is the unit of work for this task. When the phase's artifact (spec,
design doc, plan, code change, or release notes) is complete, the worker will
transition this PR from draft to ready-for-review — that is the signal that
the phase is done.
"@
}

$prUrl = & gh pr create `
  --repo $Repo `
  --base $Base `
  --head $Branch `
  --title $Title `
  --body  $Body `
  --draft
$prNum = [int]($prUrl -split '/')[-1]

try {
  & gh label create "phase:$Phase" --repo $Repo --color ededed --force *> $null
} catch { }
& gh pr edit $prNum --repo $Repo --add-label "phase:$Phase" | Out-Null

$itemId = ''
if ($Project) { $itemId = Add-PrToProject -ProjectId $Project -PrNumber $prNum -RepoName $Repo }

[ordered]@{
  pr_number       = $prNum
  branch          = $Branch
  phase           = $Phase
  created_pr      = $true
  project_item_id = $(if ($itemId) { $itemId } else { $null })
} | ConvertTo-Json -Compress
