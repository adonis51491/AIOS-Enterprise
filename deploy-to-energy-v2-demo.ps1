param(
  [string]$TargetProject = "C:\GitHub\energy-v2-demo",
  [switch]$SkipBackup
)

$ErrorActionPreference = "Stop"
$SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path -LiteralPath $TargetProject)) {
  throw "Target project not found: $TargetProject"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $TargetProject ".aios.backup.$timestamp"

if (-not $SkipBackup) {
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

  foreach ($path in @(
    ".aios",
    "scripts",
    "templates",
    "docs\checklist.md",
    "docs\codex-aios-workflow.md",
    "AGENTS.md",
    "AIOS_START.md",
    "AIOS_HANDOFF.md"
  )) {
    $source = Join-Path $TargetProject $path
    if (Test-Path -LiteralPath $source) {
      $destination = Join-Path $backupRoot $path
      New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
  }

  Write-Host "Backup created: $backupRoot" -ForegroundColor Yellow
}

Push-Location $TargetProject
try {
  & powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File (Join-Path $SourceRoot "scripts\aios.ps1") `
    update `
    -Source $SourceRoot

  if ($LASTEXITCODE -ne 0) {
    throw "AIOS update failed: $LASTEXITCODE"
  }

  & powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File ".\scripts\aios.ps1" `
    doctor

  if ($LASTEXITCODE -ne 0) {
    throw "AIOS doctor failed after deployment."
  }

  if (
    (Test-Path "STATUS.md") -and
    (Test-Path "BUGS.md") -and
    (Test-Path "ACCEPTANCE.md")
  ) {
    & powershell.exe `
      -NoProfile `
      -ExecutionPolicy Bypass `
      -File ".\scripts\aios.ps1" `
      checklist
  } else {
    Write-Host "Checklist skipped: STATUS.md, BUGS.md, or ACCEPTANCE.md is missing." -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "AIOS Enterprise deployed successfully." -ForegroundColor Green
  Write-Host "Target: $TargetProject"
  Write-Host "Next in Codex App: AIOS PLAN"
}
finally {
  Pop-Location
}
