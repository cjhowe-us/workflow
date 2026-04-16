# Release a Project v2 lock on one item, or bulk-release all items held by a
# given owner. Idempotent.
#
# Usage A (one item):
#   pwsh -NoProfile -File lock-release.ps1 -Project <PID> -Item <ITEM_ID> `
#     -OwnerField <FID> -ExpiryField <FID>
#
# Usage B (bulk by owner):
#   pwsh -NoProfile -File lock-release.ps1 -Project <PID> `
#     -OwnerMatches <LOCK_OWNER_STRING>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$Project,
  [string]$Item,
  [string]$OwnerField,
  [string]$ExpiryField,
  [string]$OwnerMatches
)

$ErrorActionPreference = 'Stop'

function Resolve-FieldIds {
  param([string]$ProjectId)
  $q = @'
query($project: ID!) {
  node(id: $project) {
    ... on ProjectV2 {
      fields(first: 50) {
        nodes { ... on ProjectV2Field { id name } }
      }
    }
  }
}
'@
  $resp = & gh api graphql -f "query=$q" -f "project=$ProjectId" | ConvertFrom-Json -Depth 20
  $map = @{}
  foreach ($f in $resp.data.node.fields.nodes) {
    if ($f.name -in @('lock_owner', 'lock_expires_at')) { $map[$f.name] = $f.id }
  }
  $map
}

if (-not $OwnerField -or -not $ExpiryField) {
  $ids = Resolve-FieldIds -ProjectId $Project
  if (-not $OwnerField)  { $OwnerField  = $ids['lock_owner'] }
  if (-not $ExpiryField) { $ExpiryField = $ids['lock_expires_at'] }
}
if (-not $OwnerField -or -not $ExpiryField) {
  Write-Error "could not resolve lock field IDs on project"
  exit 2
}

function Clear-One {
  param([string]$ItemId)
  $mut = @'
mutation($project: ID!, $item: ID!, $ownerField: ID!, $expiryField: ID!) {
  clearOwner: updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $ownerField,
    value: { text: "" }
  }) { clientMutationId }
  clearExpiry: updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $expiryField,
    value: { text: "" }
  }) { clientMutationId }
}
'@
  try {
    & gh api graphql `
      -f "query=$mut" `
      -f "project=$Project" -f "item=$ItemId" `
      -f "ownerField=$OwnerField" -f "expiryField=$ExpiryField" | Out-Null
  } catch { }
}

if ($Item) {
  Clear-One -ItemId $Item
  [ordered]@{ released = $Item } | ConvertTo-Json -Compress
  exit 0
}

if ($OwnerMatches) {
  $scan = Join-Path $PSScriptRoot 'project-query.ps1'
  if (-not (Test-Path $scan)) {
    Write-Error "project-query.ps1 missing"
    exit 2
  }
  $cleared = 0
  & pwsh -NoProfile -File $scan -ProjectId $Project | ForEach-Object {
    if (-not $_) { return }
    $rec = $_ | ConvertFrom-Json
    if ($rec.item_id -and ($rec.lock_owner -like "*$OwnerMatches*")) {
      Clear-One -ItemId $rec.item_id
      $cleared++
    }
  }
  [ordered]@{ released_count = $cleared } | ConvertTo-Json -Compress
  exit 0
}

Write-Error "either -Item or -OwnerMatches required"
exit 2
