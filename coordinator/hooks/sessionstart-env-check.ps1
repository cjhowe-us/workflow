# SessionStart hook (PowerShell). Hard-blocks if agent teams is not enabled.
# Warns about missing gh auth / project config but does not block those.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Read stdin payload (hooks receive JSON on stdin). Ignore if empty.
$inputJson = ''
if (-not [Console]::IsInputRedirected) {
  $inputJson = ''
} else {
  $inputJson = [Console]::In.ReadToEnd()
}

# Agent teams experimental flag — REQUIRED.
if ($env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -ne '1') {
  $pluginRoot = $env:CLAUDE_PLUGIN_ROOT
  if (-not $pluginRoot) {
    $pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  }
  [Console]::Error.WriteLine("coordinator plugin: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not set to 1.")
  [Console]::Error.WriteLine("The orchestrator cannot dispatch workers without agent teams.")
  [Console]::Error.WriteLine("")
  [Console]::Error.WriteLine("Run one of these to persist it for your shell, then restart your terminal:")
  [Console]::Error.WriteLine("  bash/zsh/fish:  $pluginRoot/scripts/ensure-agent-teams-env.sh")
  [Console]::Error.WriteLine("  PowerShell:     pwsh -NoProfile -File $pluginRoot/scripts/ensure-agent-teams-env.ps1")
  exit 2
}

$warnings = New-Object System.Collections.Generic.List[string]

# gh CLI present and authenticated
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  $warnings.Add("gh CLI is not installed — coordinator needs it for GitHub Project v2 mutations.")
} else {
  & gh auth status *> $null
  if ($LASTEXITCODE -ne 0) {
    $warnings.Add("gh CLI is not authenticated — run 'gh auth login' with read:project, project, repo scopes.")
  }
}

# Project config file
$cwd = $null
if ($inputJson) {
  try {
    $cwd = ($inputJson | ConvertFrom-Json).cwd
  } catch { }
}
if (-not $cwd) { $cwd = (Get-Location).Path }
$cfg = Join-Path $cwd '.claude/coordinator.local.md'
if (-not (Test-Path $cfg)) {
  $warnings.Add("No .claude/coordinator.local.md found at $cwd — orchestrator will prompt for project_id on first /coordinator invocation.")
}

if ($warnings.Count -eq 0) {
  '{}'
  exit 0
}

$msg = "coordinator plugin warnings:`n"
foreach ($w in $warnings) { $msg += "  - $w`n" }

[ordered]@{
  hookSpecificOutput = [ordered]@{
    hookEventName     = 'SessionStart'
    additionalContext = $msg
  }
} | ConvertTo-Json -Compress -Depth 10
