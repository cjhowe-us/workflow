# SubagentStop / TaskCompleted hook (PowerShell). Clears Project v2 lock fields
# for any items whose lock_owner matches the stopped worker's id. Idempotent.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$inputJson = ''
if ([Console]::IsInputRedirected) {
  $inputJson = [Console]::In.ReadToEnd()
}

if (-not $inputJson) { '{}'; exit 0 }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { '{}'; exit 0 }

try {
  $payload = $inputJson | ConvertFrom-Json
} catch {
  '{}'; exit 0
}

$agentId = $payload.agent_id
if (-not $agentId) { $agentId = $payload.subagent_id }
if (-not $agentId) { $agentId = $payload.task_id }
if (-not $agentId) { '{}'; exit 0 }

# Skip if not a coordinator worker
$subagentType = $payload.subagent_type
if (-not $subagentType) { $subagentType = $payload.agent_type }
if ($subagentType -and $subagentType -ne 'coordinator-worker') { '{}'; exit 0 }

$cwd = $payload.cwd
if (-not $cwd) { $cwd = (Get-Location).Path }
$cfg = Join-Path $cwd '.claude/coordinator.local.md'
if (-not (Test-Path $cfg)) { '{}'; exit 0 }

$projectId = $null
foreach ($line in Get-Content -Path $cfg) {
  if ($line -match '^project_id:\s*(?:"|'')?([^"''\s]+)(?:"|'')?\s*$') {
    $projectId = $Matches[1]
    break
  }
}
if (-not $projectId) { '{}'; exit 0 }

$pluginRoot = $env:CLAUDE_PLUGIN_ROOT
if (-not $pluginRoot) {
  $pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

# Best-effort; swallow errors so the hook never propagates failure.
try {
  & pwsh -NoProfile -File (Join-Path $pluginRoot 'scripts/lock-release.ps1') `
    -Project $projectId -OwnerMatches $agentId *> $null
} catch { }

'{}'
