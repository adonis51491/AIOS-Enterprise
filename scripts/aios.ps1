param(
  [string]$Command = "doctor",
  [string]$Target = "",
  [string]$Source = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Header($text) {
  Write-Host ""
  Write-Host "== AIOS :: $text ==" -ForegroundColor Cyan
}

function Test-File($path) {
  if (Test-Path $path) {
    Write-Host "[OK] $path" -ForegroundColor Green
  } else {
    Write-Host "[MISSING] $path" -ForegroundColor Red
  }
}

function Ensure-Dir($path) {
  if (!(Test-Path $path)) {
    New-Item -ItemType Directory -Path $path | Out-Null
  }
}

function Copy-AiosContent($from, $to) {
  if (!(Test-Path $from)) {
    throw "Source not found: $from"
  }
  Ensure-Dir $to
  Copy-Item "$from\*" $to -Recurse -Force
}

function Resolve-Source($Source) {
  if ($Source -ne "") {
    return $Source
  }

  $default = "C:\GitHub\AIOS-Enterprise"
  if (Test-Path $default) {
    return $default
  }

  throw "AIOS source not found. Use: pwsh scripts/aios.ps1 install -Source C:\GitHub\AIOS-Enterprise"
}

switch ($Command) {
  "doctor" {
    Write-Header "Doctor"
    Test-File ".aios/aios.config.yaml"
    Test-File ".aios/kernel/kernel.yaml"
    Test-File ".aios/runtime/runtime.yaml"
    Test-File ".aios/workflows/bugfix.yaml"
    Test-File ".aios/policies/default.yaml"
    Test-File ".aios/version.json"
    Test-File ".aios/installer/manifest.json"
    Write-Host ""
    Write-Host "AIOS doctor completed."
  }

  "install" {
    Write-Header "Install"
    $src = Resolve-Source $Source
    Write-Host "Source: $src"
    Write-Host "Target: $(Get-Location)"

    Copy-AiosContent "$src\.aios" ".\.aios"
    Copy-AiosContent "$src\scripts" ".\scripts"
    Copy-AiosContent "$src\templates" ".\templates"

    Ensure-Dir ".\docs"
    if (Test-Path "$src\docs\runtime.md") {
      Copy-Item "$src\docs\runtime.md" ".\docs\runtime.md" -Force
    }

    Write-Host "AIOS installed."
  }

  "update" {
    Write-Header "Update"
    $src = Resolve-Source $Source
    Write-Host "Source: $src"
    Write-Host "Target: $(Get-Location)"

    Copy-AiosContent "$src\.aios" ".\.aios"
    Copy-AiosContent "$src\scripts" ".\scripts"
    Copy-AiosContent "$src\templates" ".\templates"

    Ensure-Dir ".\docs"
    if (Test-Path "$src\docs\runtime.md") {
      Copy-Item "$src\docs\runtime.md" ".\docs\runtime.md" -Force
    }

    Write-Host "AIOS updated."
  }

  "sync" {
    Write-Header "Sync"
    $src = Resolve-Source $Source
    Copy-AiosContent "$src\.aios" ".\.aios"
    Copy-AiosContent "$src\scripts" ".\scripts"
    Copy-AiosContent "$src\templates" ".\templates"
    Write-Host "AIOS sync completed."
  }

  "run" {
    Write-Header "Run"
    if ($Target -eq "") {
      throw "Usage: pwsh scripts/aios.ps1 run BUG-001"
    }
    Write-Host "Target: $Target"
    Write-Host "Use templates/AIOS_V8_CLI_PROMPT.md as the execution prompt."
    Write-Host "Runtime: PLAN -> IMPLEMENT -> REVIEW -> VERIFY -> RELEASE"
  }

  "release" {
    Write-Header "Release"
    Write-Host "Release Manager should update version, changelog, release notes, commit message and PR description."
  }

  "resume" {
    Write-Header "Resume"
    Test-File ".aios/snapshots/latest.json"
  }

  "rollback" {
    Write-Header "Rollback"
    Write-Host "Rollback requires a selected snapshot from .aios/snapshots/"
  }

  "stats" {
    Write-Header "Stats"
    Write-Host "Telemetry folder: .aios/telemetry/"
  }

  default {
    throw "Unknown command: $Command"
  }
}
