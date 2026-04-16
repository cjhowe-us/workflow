# Query a GitHub Project v2 for every PR in scope, including lock fields,
# phase label, and `blocked by` relationships. Emits one JSON record per line
# on stdout.
#
# Only pull requests are emitted — issues are filtered out because the
# coordinator model uses PRs as the sole unit of work.
#
# Usage:
#   pwsh -NoProfile -File project-query.ps1 -ProjectId <PVT_...>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Error "gh CLI is required"
  exit 2
}

$query = @'
query($project: ID!, $after: String) {
  node(id: $project) {
    ... on ProjectV2 {
      items(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          content {
            __typename
            ... on PullRequest {
              number state isDraft
              repository { nameWithOwner }
              headRefName
              labels(first: 20) { nodes { name } }
            }
          }
          fieldValues(first: 50) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldTextValue {
                text field { ... on ProjectV2Field { name } }
              }
            }
          }
        }
      }
    }
  }
}
'@

$cursor = $null
while ($true) {
  $ghArgs = @(
    'api', 'graphql',
    '-f', "query=$query",
    '-f', "project=$ProjectId"
  )
  if ($null -ne $cursor -and $cursor -ne '') {
    $ghArgs += @('-f', "after=$cursor")
  }

  $resp = & gh @ghArgs | ConvertFrom-Json -Depth 20

  foreach ($node in $resp.data.node.items.nodes) {
    if ($node.content.__typename -ne 'PullRequest') { continue }

    $fvs       = @($node.fieldValues.nodes)
    $owner     = ($fvs | Where-Object { $_.field.name -eq 'lock_owner' }      | Select-Object -First 1).text
    $expiresAt = ($fvs | Where-Object { $_.field.name -eq 'lock_expires_at' } | Select-Object -First 1).text
    if ($null -eq $owner)     { $owner     = '' }
    if ($null -eq $expiresAt) { $expiresAt = '' }

    $phase = ''
    foreach ($lbl in @($node.content.labels.nodes)) {
      if ($lbl.name -like 'phase:*') { $phase = $lbl.name.Substring(6); break }
    }

    $c = $node.content
    $record = [ordered]@{
      item_id         = $node.id
      number          = $c.number
      repo            = $c.repository.nameWithOwner
      state           = ($c.state.ToString()).ToLower()
      is_draft        = [bool]$c.isDraft
      head_ref_name   = $c.headRefName
      phase           = $phase
      lock_owner      = $owner
      lock_expires_at = $expiresAt
    }
    $record | ConvertTo-Json -Compress
  }

  if (-not $resp.data.node.items.pageInfo.hasNextPage) { break }
  $cursor = $resp.data.node.items.pageInfo.endCursor
}
