# Acquire a Project v2 lock on a single item.
#
# Usage:
#   pwsh -NoProfile -File lock-acquire.ps1 `
#     -Project <PID> -Item <ITEM_ID> `
#     -OwnerField <FID> -ExpiryField <FID> `
#     -Owner <LOCK_OWNER_STRING> -ExpiresAt <YYYY-MM-DDTHH:MM:SSZ>
#
# Exit 0 on success. Exit 1 on race. Exit 2 on error.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$Project,
  [Parameter(Mandatory = $true)] [string]$Item,
  [Parameter(Mandatory = $true)] [string]$OwnerField,
  [Parameter(Mandatory = $true)] [string]$ExpiryField,
  [Parameter(Mandatory = $true)] [string]$Owner,
  [Parameter(Mandatory = $true)] [string]$ExpiresAt
)

$ErrorActionPreference = 'Stop'

$nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

function Read-Lock {
  param([string]$ItemId)
  $q = @'
query($item: ID!) {
  node(id: $item) {
    ... on ProjectV2Item {
      fieldValues(first: 50) {
        nodes {
          __typename
          ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2Field { name } } }
        }
      }
    }
  }
}
'@
  & gh api graphql -f "query=$q" -f "item=$ItemId" | ConvertFrom-Json -Depth 20
}

$current = Read-Lock -ItemId $Item
$fvs     = @($current.data.node.fieldValues.nodes)
$curOwner  = ($fvs | Where-Object { $_.field.name -eq 'lock_owner' }       | Select-Object -First 1).text
$curExpiry = ($fvs | Where-Object { $_.field.name -eq 'lock_expires_at' }  | Select-Object -First 1).text
if ($null -eq $curOwner)  { $curOwner  = '' }
if ($null -eq $curExpiry) { $curExpiry = '' }

# ISO-8601 Zulu UTC sorts lexicographically in the same order as by time.
if ($curOwner -ne '' -and $curExpiry -ne '' -and [string]::Compare($curExpiry, $nowIso) -gt 0) {
  Write-Error "raced: held by $curOwner until $curExpiry"
  exit 1
}

$mut = @'
mutation(
  $project: ID!, $item: ID!,
  $ownerField: ID!, $owner: String!,
  $expiryField: ID!, $expiry: String!
) {
  setOwner: updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $ownerField, value: { text: $owner }
  }) { clientMutationId }
  setExpiry: updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $expiryField, value: { text: $expiry }
  }) { clientMutationId }
}
'@

& gh api graphql `
  -f "query=$mut" `
  -f "project=$Project" -f "item=$Item" `
  -f "ownerField=$OwnerField" -f "owner=$Owner" `
  -f "expiryField=$ExpiryField" -f "expiry=$ExpiresAt" | Out-Null

# Random backoff 100-500ms, then verify ownership.
Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)

$verify    = Read-Lock -ItemId $Item
$fvs2      = @($verify.data.node.fieldValues.nodes)
$verOwner  = ($fvs2 | Where-Object { $_.field.name -eq 'lock_owner' } | Select-Object -First 1).text
if ($null -eq $verOwner) { $verOwner = '' }

if ($verOwner -ne $Owner) {
  # Someone else raced to overwrite after our write. Release our half-stamp and bail.
  try {
    & (Join-Path $PSScriptRoot 'lock-release.ps1') `
      -Project $Project -Item $Item `
      -OwnerField $OwnerField -ExpiryField $ExpiryField 2>$null | Out-Null
  } catch { }
  Write-Error "raced: overwritten by $verOwner after write"
  exit 1
}

[ordered]@{ acquired = $true; owner = $Owner; expires_at = $ExpiresAt; at = $nowIso } |
  ConvertTo-Json -Compress
