# Parity test: every coordinator/{hooks,scripts}/*.sh must have a sibling .ps1,
# and every .ps1 must parse under pwsh (Parse errors fail the test).
#
# Runs cross-platform under pwsh (Windows/macOS/Linux). Exit 0 = pass,
# non-zero = fail.
#
# Usage:
#   pwsh -NoProfile -File coordinator/tests/test-parity.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$failures = New-Object System.Collections.Generic.List[string]
$checked  = 0

$dirs = @(
  (Join-Path $pluginRoot 'hooks'),
  (Join-Path $pluginRoot 'scripts')
)

foreach ($dir in $dirs) {
  if (-not (Test-Path $dir)) { continue }

  $shFiles = Get-ChildItem -Path $dir -Filter '*.sh' -File
  foreach ($sh in $shFiles) {
    $checked++
    $psPath = [System.IO.Path]::ChangeExtension($sh.FullName, '.ps1')
    if (-not (Test-Path $psPath)) {
      $failures.Add("MISSING: $($sh.FullName) -> expected $psPath")
      continue
    }

    # Basic parse check: tokenize + parse the PowerShell file. Any parse errors fail.
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
      $psPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
      foreach ($e in $parseErrors) {
        $failures.Add("PARSE ERROR: $psPath — $($e.Message) (line $($e.Extent.StartLineNumber))")
      }
    }
  }

  # Also flag orphan .ps1 (no sibling .sh) unless the bare .ps1 is the one-off case.
  $psFiles = Get-ChildItem -Path $dir -Filter '*.ps1' -File
  foreach ($ps in $psFiles) {
    $shPath = [System.IO.Path]::ChangeExtension($ps.FullName, '.sh')
    if (-not (Test-Path $shPath)) {
      $failures.Add("ORPHAN: $($ps.FullName) has no sibling .sh (parity is bidirectional)")
    }
  }
}

if ($failures.Count -eq 0) {
  Write-Host "parity OK — checked $checked .sh file(s), all .ps1 companions present and parseable"
  exit 0
}

Write-Host "parity FAILED:" -ForegroundColor Red
foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
exit 1
