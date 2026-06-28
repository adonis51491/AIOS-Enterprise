param(
  [string]$AIOSRoot = 'C:\GitHub\AIOS-Enterprise',
  [string]$TargetProject = 'C:\GitHub\energy-v2-demo'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $AIOSRoot)) { throw "AIOSRoot not found: $AIOSRoot" }
if (-not (Test-Path $TargetProject)) { throw "TargetProject not found: $TargetProject" }

$backup = Join-Path $TargetProject ('.aios.backup.semi-auto.' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (Test-Path (Join-Path $TargetProject '.aios')) {
  Copy-Item (Join-Path $TargetProject '.aios') $backup -Recurse -Force
  Write-Host "Backup: $backup"
}

$items = @('scripts\aios-semi-auto.ps1','templates\prompts','docs\semi-auto-fix.md','.aios\workflows\semi-auto-fix.yaml','.aios\policies\semi-auto-fix.yaml','.aios\runtime\semi-auto-state.json')
foreach ($item in $items) {
  $src = Join-Path $AIOSRoot $item
  $dst = Join-Path $TargetProject $item
  if (Test-Path $src) {
    $parent = Split-Path -Parent $dst
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Copy-Item $src $dst -Recurse -Force
    Write-Host "Deployed: $item"
  }
}

Write-Host "Semi-Auto Fix deployed to $TargetProject"
Write-Host "Next: cd $TargetProject; powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-semi-auto.ps1 status"
