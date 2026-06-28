param(
  [string]$AIOSRoot = 'C:\GitHub\AIOS-Enterprise'
)

$ErrorActionPreference = 'Stop'
$SourceRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $AIOSRoot)) { throw "AIOSRoot not found: $AIOSRoot" }

$items = @('scripts','templates','.aios','docs','version.json','README.md')
foreach ($item in $items) {
  $src = Join-Path $SourceRoot $item
  $dst = Join-Path $AIOSRoot $item
  if (Test-Path $src) {
    Copy-Item $src $dst -Recurse -Force
    Write-Host "Installed: $item"
  }
}

Write-Host "AIOS Semi-Auto Fix installed to $AIOSRoot"
Write-Host "Next: cd $AIOSRoot; git status; git add .; git commit -m 'feat(aios): add semi-auto fix workflow'; git push"
