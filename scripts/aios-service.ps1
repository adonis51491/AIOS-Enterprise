param(
  [Parameter(Position = 0)]
  [ValidateSet("install","start","stop","status","uninstall","run-once")]
  [string]$Command = "status",

  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$statePath = Join-Path $ProjectRoot ".aios\runtime\watch-state.json"
$watchScript = Join-Path $ProjectRoot "scripts\aios-watch.ps1"

function Write-State([bool]$enabled, [string]$status) {
  $state = [ordered]@{
    schema_version = 1
    enabled = $enabled
    last_scan_at = $null
    last_fingerprint = $null
    status = $status
  }
  New-Item -ItemType Directory -Path (Split-Path $statePath -Parent) -Force | Out-Null
  $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
}

switch ($Command) {
  "install" {
    Write-State $false "installed"
    Write-Host "NightWatch baseline installed. It is not auto-started." -ForegroundColor Green
  }
  "start" {
    Write-State $true "running"
    Write-Host "NightWatch enabled. Use watch-once or schedule it explicitly." -ForegroundColor Green
  }
  "stop" {
    Write-State $false "stopped"
    Write-Host "NightWatch stopped." -ForegroundColor Yellow
  }
  "status" {
    if (Test-Path $statePath) {
      Get-Content $statePath -Encoding UTF8
    } else {
      Write-Host "NightWatch is not installed."
    }
  }
  "uninstall" {
    if (Test-Path $statePath) { Remove-Item $statePath -Force }
    Write-Host "NightWatch state removed." -ForegroundColor Yellow
  }
  "run-once" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $watchScript -ProjectRoot $ProjectRoot -Once
    exit $LASTEXITCODE
  }
}
