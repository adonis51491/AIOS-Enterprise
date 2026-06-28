$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$required = @(
  "version.json",
  ".aios\version.json",
  ".aios\aios.config.yaml",
  ".aios\kernel\kernel.yaml",
  ".aios\runtime\runtime.yaml",
  ".aios\policies\default.yaml",
  ".aios\workflows\bugfix.yaml",
  ".aios\installer\manifest.json",
  "scripts\aios.ps1",
  "scripts\aios-checklist.ps1",
  "scripts\aios-watch.ps1",
  "scripts\aios-service.ps1",
  "templates\reports\TODAY_CHECKLIST_TEMPLATE.md",
  "AGENTS.md",
  "deploy-to-energy-v2-demo.ps1"
)

$missing = @()
foreach ($item in $required) {
  if (-not (Test-Path (Join-Path $root $item))) {
    $missing += $item
  }
}

if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "[MISSING] $_" -ForegroundColor Red }
  exit 1
}

Write-Host "Package structure: PASS" -ForegroundColor Green
