# Extend a Project v2 lock's lock_expires_at. Caller must already hold the lock.
#
# Usage:
#   pwsh -NoProfile -File lock-heartbeat.ps1 `
#     -Project <PID> -Item <ITEM_ID> `
#     -ExpiryField <FID> -ExpiresAt <YYYY-MM-DDTHH:MM:SSZ> `
#     [-OwnerField <FID> -ExpectedOwner <OWNER>]
#
# If -OwnerField and -ExpectedOwner are given, verifies current owner first;
# exits 1 if the lock has been stolen.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$Project,
  [Parameter(Mandatory = $true)] [string]$Item,
  [Parameter(Mandatory = $true)] [string]$ExpiryField,
  [Parameter(Mandatory = $true)] [string]$ExpiresAt,
  [string]$OwnerField,
  [string]$ExpectedOwner
)

$ErrorActionPreference = 'Stop'

if ($OwnerField -and $ExpectedOwner) {
  $q = @'
query($item: ID!) {
  node(id: $item) {
    ... on ProjectV2Item {
      fieldValues(first: 50) {
        nodes {
          ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2Field { name } } }
        }
      }
    }
  }
}
'@
  $resp = & gh api graphql -f "query=$q" -f "item=$Item" | ConvertFrom-Json -Depth 20
  $curOwner = ($resp.data.node.fieldValues.nodes |
    Where-Object { $_.field.name -eq 'lock_owner' } |
    Select-Object -First 1).text
  if ($null -eq $curOwner) { $curOwner = '' }
  if ($curOwner -ne $ExpectedOwner) {
    Write-Error "stolen: current owner is '$curOwner' (expected '$ExpectedOwner')"
    exit 1
  }
}

$mut = @'
mutation($project: ID!, $item: ID!, $expiryField: ID!, $expiry: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $project, itemId: $item, fieldId: $expiryField, value: { text: $expiry }
  }) { clientMutationId }
}
'@

& gh api graphql `
  -f "query=$mut" `
  -f "project=$Project" -f "item=$Item" `
  -f "expiryField=$ExpiryField" -f "expiry=$ExpiresAt" | Out-Null

[ordered]@{ heartbeat = 'ok'; expires_at = $ExpiresAt } | ConvertTo-Json -Compress
