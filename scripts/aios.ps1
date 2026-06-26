param(
  [string]$Command = "doctor",
  [string]$Target = ""
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

switch ($Command) {
  "doctor" {
    Write-Header "Doctor"
    Test-File ".aios/aios.config.yaml"
    Test-File ".aios/kernel/kernel.yaml"
    Test-File ".aios/runtime/runtime.yaml"
    Test-File ".aios/workflows/bugfix.yaml"
    Test-File ".aios/policies/default.yaml"
    Test-File ".aios/version.json"
    Write-Host ""
    Write-Host "AIOS doctor completed."
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
