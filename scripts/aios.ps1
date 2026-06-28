param(
  [Parameter(Position = 0)]
  [string]$Command = "doctor",

  [Parameter(Position = 1)]
  [string]$Target = "",

  [string]$Source = "",

  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Header([string]$Text) {
  Write-Host ""
  Write-Host "== AIOS :: $Text ==" -ForegroundColor Cyan
}

function Ensure-Directory([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Resolve-AiosSource([string]$RequestedSource) {
  if (-not [string]::IsNullOrWhiteSpace($RequestedSource)) {
    if (-not (Test-Path -LiteralPath $RequestedSource)) {
      throw "AIOS source not found: $RequestedSource"
    }
    return (Resolve-Path -LiteralPath $RequestedSource).Path
  }

  $defaultSource = "C:\GitHub\AIOS-Enterprise"
  if (Test-Path -LiteralPath $defaultSource) { return $defaultSource }

  throw "AIOS source not found. Use -Source C:\GitHub\AIOS-Enterprise"
}

function Copy-ManagedPath([string]$SourceRoot, [string]$RelativePath) {
  $from = Join-Path $SourceRoot $RelativePath
  $to = Join-Path (Get-Location).Path $RelativePath

  if (-not (Test-Path -LiteralPath $from)) { return }

  if ((Get-Item -LiteralPath $from).PSIsContainer) {
    Ensure-Directory $to
    Get-ChildItem -LiteralPath $from -Force | Copy-Item -Destination $to -Recurse -Force
  } else {
    Ensure-Directory (Split-Path $to -Parent)
    Copy-Item -LiteralPath $from -Destination $to -Force
  }
}

function Sync-Aios([string]$SourceRoot) {
  $managed = @(
    ".aios\aios.config.yaml",
    ".aios\version.json",
    ".aios\kernel",
    ".aios\policies",
    ".aios\workflows",
    ".aios\installer",
    ".aios\daemon",
    ".aios\detectors",
    ".aios\generators",
    ".aios\context",
    ".aios\prompts",
    ".aios\runtime\runtime.yaml",
    "scripts",
    "templates",
    "docs\checklist.md",
    "docs\codex-aios-workflow.md",
    "docs\runtime.md",
    "docs\auto-bug.md",
    "docs\nightwatch.md",
    "AGENTS.md",
    "AIOS_START.md",
    "AIOS_HANDOFF.md"
  )

  foreach ($item in $managed) {
    Copy-ManagedPath -SourceRoot $SourceRoot -RelativePath $item
  }

  foreach ($dir in @(
    ".aios\reports",
    ".aios\queue",
    ".aios\inbox",
    ".aios\logs",
    "docs\bugs",
    "docs\acceptance"
  )) {
    Ensure-Directory $dir
  }

  foreach ($state in @(
    ".aios\runtime\project-state.json",
    ".aios\runtime\watch-state.json"
  )) {
    if (-not (Test-Path $state)) {
      Copy-ManagedPath -SourceRoot $SourceRoot -RelativePath $state
    }
  }
}

function Add-AiosGitIgnore {
  if (-not (Test-Path ".gitignore")) {
    New-Item -ItemType File -Path ".gitignore" | Out-Null
  }

  $required = @(
    ".aios/reports/TODAY_CHECKLIST.md",
    ".aios/logs/",
    "*.bak",
    "AGENTS.md.bak.*"
  )
  $current = Get-Content ".gitignore" -ErrorAction SilentlyContinue

  foreach ($line in $required) {
    if ($current -notcontains $line) {
      Add-Content ".gitignore" $line -Encoding UTF8
    }
  }
}

switch ($Command.ToLowerInvariant()) {
  "doctor" {
    Write-Header "Doctor"
    $required = @(
      ".aios/aios.config.yaml",
      ".aios/kernel/kernel.yaml",
      ".aios/runtime/runtime.yaml",
      ".aios/workflows/bugfix.yaml",
      ".aios/workflows/solve.yaml",
      ".aios/policies/default.yaml",
      ".aios/version.json",
      ".aios/installer/manifest.json",
      ".aios/daemon/daemon.yaml",
      ".aios/detectors/bug-detector.yaml",
      ".aios/generators/acceptance-generator.yaml",
      ".aios/context/context-builder.yaml",
      ".aios/runtime/watch-state.json",
      "scripts/aios-watch.ps1",
      "scripts/aios-capture.ps1",
      "scripts/aios-service.ps1",
      "scripts/aios-checklist.ps1",
      "templates/reports/TODAY_CHECKLIST_TEMPLATE.md",
      "docs/checklist.md",
      "docs/codex-aios-workflow.md",
      "AGENTS.md"
    )

    $missing = 0
    foreach ($file in $required) {
      if (Test-Path -LiteralPath $file) {
        Write-Host "[OK] $file" -ForegroundColor Green
      } else {
        Write-Host "[MISSING] $file" -ForegroundColor Red
        $missing++
      }
    }

    if ($missing -eq 0) {
      Write-Host "AIOS doctor completed: HEALTHY" -ForegroundColor Green
      exit 0
    }

    Write-Host "AIOS doctor completed: $missing required file(s) missing." -ForegroundColor Red
    exit 1
  }

  "install" {
    Write-Header "Install"
    $resolved = Resolve-AiosSource $Source
    Sync-Aios $resolved
    Add-AiosGitIgnore
    Write-Host "AIOS installed." -ForegroundColor Green
  }

  "update" {
    Write-Header "Update"
    $resolved = Resolve-AiosSource $Source
    Sync-Aios $resolved
    Add-AiosGitIgnore
    Write-Host "AIOS updated." -ForegroundColor Green
  }

  "checklist" {
    Write-Header "Checklist"
    $script = Join-Path $PSScriptRoot "aios-checklist.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -ProjectRoot (Get-Location).Path
    if ($LASTEXITCODE -ne 0) { throw "Checklist generation failed: $LASTEXITCODE" }
  }

  "watch-install" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\aios-service.ps1" install -ProjectRoot (Get-Location).Path
  }
  "watch-start" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\aios-service.ps1" start -ProjectRoot (Get-Location).Path
  }
  "watch-stop" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\aios-service.ps1" stop -ProjectRoot (Get-Location).Path
  }
  "watch-status" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\aios-service.ps1" status -ProjectRoot (Get-Location).Path
  }
  "watch-uninstall" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\aios-service.ps1" uninstall -ProjectRoot (Get-Location).Path
  }
  "watch-once" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\aios-service.ps1" run-once -ProjectRoot (Get-Location).Path
  }

  "queue" {
    Write-Header "Queue"
    Ensure-Directory ".aios\queue"
    $items = Get-ChildItem ".aios\queue" -Filter "*.json" -ErrorAction SilentlyContinue
    if (-not $items) {
      Write-Host "Queue is empty."
    } else {
      foreach ($item in $items) {
        $data = Get-Content $item.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "$($data.bug_id) [$($data.status)] $($data.source_log)"
      }
    }
  }

  "codex-plan" {
    Get-Content ".aios\prompts\CODEX_PLAN.md" -Encoding UTF8
  }
  "codex-implement" {
    Get-Content ".aios\prompts\CODEX_IMPLEMENT.md" -Encoding UTF8
  }
  "codex-validate" {
    Get-Content ".aios\prompts\CODEX_VALIDATE.md" -Encoding UTF8
  }

  "help" {
    @"
AIOS Enterprise commands:

  doctor             Check required files
  install            Install from AIOS source
  update             Update managed AIOS files safely
  checklist          Generate TODAY_CHECKLIST.md
  watch-install      Initialize NightWatch
  watch-start        Enable NightWatch state
  watch-stop         Stop NightWatch state
  watch-status       Show NightWatch state
  watch-once         Scan the log once
  queue              Show queued bugs
  codex-plan         Print the Codex PLAN prompt
  codex-implement    Print the Codex IMPLEMENT prompt
  codex-validate     Print the Codex VALIDATE prompt
"@
  }

  default {
    throw "Unknown command: $Command. Use: scripts\aios.ps1 help"
  }
}
