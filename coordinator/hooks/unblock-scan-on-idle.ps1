# SubagentStop / TaskCompleted / TeammateIdle hook (PowerShell). Tells the
# orchestrator to rescan for newly dispatchable items. Debounced (default 30s)
# to avoid thrash under rapid event bursts.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$debounceSec = 30
if ($env:COORDINATOR_UNBLOCK_HOOK_DEBOUNCE_SEC) {
  [int]::TryParse($env:COORDINATOR_UNBLOCK_HOOK_DEBOUNCE_SEC, [ref]$debounceSec) | Out-Null
}

# Debounce file lives outside the repo.
$stateDir = if ($env:XDG_STATE_HOME) {
  Join-Path $env:XDG_STATE_HOME 'coordinator'
} elseif ($IsWindows) {
  Join-Path $env:LOCALAPPDATA 'coordinator'
} else {
  Join-Path $HOME '.local/state/coordinator'
}

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$pending = Join-Path $stateDir 'unblock-pending.json'

$nowEpoch  = [int64](Get-Date -UFormat %s)
$prevEpoch = 0
if (Test-Path $pending) {
  try {
    $prev = Get-Content -Raw -Path $pending | ConvertFrom-Json
    if ($prev.last_emit_epoch) { $prevEpoch = [int64]$prev.last_emit_epoch }
  } catch { }
}

if (($nowEpoch - $prevEpoch) -lt $debounceSec) {
  '{}'
  exit 0
}

[ordered]@{ last_emit_epoch = $nowEpoch } | ConvertTo-Json -Compress | Set-Content -Path $pending

[ordered]@{
  hookSpecificOutput = [ordered]@{
    additionalContext = 'coordinator: rescan the project for newly dispatchable items and fill any free worker slots.'
  }
} | ConvertTo-Json -Compress -Depth 10
