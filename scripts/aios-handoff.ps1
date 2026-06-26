param(
  [string]$ProjectRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Get-Location).Path
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $ProjectRoot

$VersionPath = Join-Path $ProjectRoot ".aios\version.json"
$StatePath = Join-Path $ProjectRoot ".aios\runtime\project-state.json"
$WatchStatePath = Join-Path $ProjectRoot ".aios\runtime\watch-state.json"
$QueuePath = Join-Path $ProjectRoot ".aios\queue"
$BugPath = Join-Path $ProjectRoot "docs\bugs"
$AcceptancePath = Join-Path $ProjectRoot "docs\acceptance"
$HandoffPath = Join-Path $ProjectRoot "AIOS_HANDOFF.md"

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $null
  }

  return $raw | ConvertFrom-Json
}

function Get-CurrentBranch {
  try {
    $value = (& git branch --show-current 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return "unknown" }
    return $value
  } catch {
    return "unknown"
  }
}

function Get-WorkingTreeState {
  try {
    $status = (& git status --porcelain 2>$null)
    if ($null -eq $status -or @($status).Count -eq 0) {
      return "clean"
    }
    return "dirty"
  } catch {
    return "unknown"
  }
}

function Get-NightWatchStatus {
  $taskName = "AIOS-NightWatch-" + (($ProjectRoot -replace '[^A-Za-z0-9]', '_').Trim('_'))

  try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -eq $task) {
      return @{
        installed = $false
        state = "not_installed"
      }
    }

    return @{
      installed = $true
      state = [string]$task.State
    }
  } catch {
    return @{
      installed = $null
      state = "unknown"
    }
  }
}

function Get-LatestFile {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Filter
  )

  if (-not (Test-Path -LiteralPath $Directory)) {
    return $null
  }

  $item = Get-ChildItem -LiteralPath $Directory -Filter $Filter -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if ($null -eq $item) {
    return $null
  }

  return $item
}

$version = Read-JsonFile -Path $VersionPath
if ($null -eq $version) {
  throw "Missing or unreadable AIOS version file: $VersionPath"
}

$watchState = Read-JsonFile -Path $WatchStatePath
$nightWatch = Get-NightWatchStatus
$latestQueue = Get-LatestFile -Directory $QueuePath -Filter "*.json"
$latestBug = Get-LatestFile -Directory $BugPath -Filter "*.md"
$latestAcceptance = Get-LatestFile -Directory $AcceptancePath -Filter "*.md"

$latestQueuedBugId = $null
if ($null -ne $latestQueue) {
  try {
    $queueData = Read-JsonFile -Path $latestQueue.FullName
    $latestQueuedBugId = $queueData.bug_id
  } catch {
    $latestQueuedBugId = [System.IO.Path]::GetFileNameWithoutExtension($latestQueue.Name)
  }
}

$state = [ordered]@{
  schema_version = "1.0"
  project = [ordered]@{
    name = Split-Path -Leaf $ProjectRoot
    path = $ProjectRoot
    aios_source = "C:\GitHub\AIOS-Enterprise"
  }
  aios = [ordered]@{
    version = [string]$version.version
    codename = [string]$version.codename
    runtime = [string]$version.runtime
    channel = [string]$version.channel
  }
  git = [ordered]@{
    branch = Get-CurrentBranch
    working_tree = Get-WorkingTreeState
  }
  nightwatch = [ordered]@{
    installed = $nightWatch.installed
    state = $nightWatch.state
    last_bug_id = if ($null -ne $watchState) { $watchState.last_bug_id } else { $null }
  }
  runtime = [ordered]@{
    phase = "PLAN"
    latest_queued_bug = $latestQueuedBugId
    latest_bug_file = if ($null -ne $latestBug) { $latestBug.FullName.Replace($ProjectRoot + "\", "") } else { $null }
    latest_acceptance_file = if ($null -ne $latestAcceptance) { $latestAcceptance.FullName.Replace($ProjectRoot + "\", "") } else { $null }
  }
  completed = @(
    "AIOS runtime installation flow",
    "Automatic bug and acceptance generation",
    "NightWatch scheduled task",
    "Duplicate error fingerprint protection",
    "Cross-chat startup and handoff files"
  )
  known_issues = @()
  next_action = if ($null -ne $latestQueuedBugId) {
    "Process queued bug $latestQueuedBugId under PLAN."
  } else {
    "No queued bug. Keep NightWatch running and use monitored commands."
  }
  updated_at = (Get-Date).ToString("o")
}

$state |
  ConvertTo-Json -Depth 8 |
  Set-Content -LiteralPath $StatePath -Encoding UTF8

$statusSection = @"
<!-- AIOS_GENERATED_STATUS_START -->
## Generated Current Status

- Updated at: $($state.updated_at)
- AIOS version: $($state.aios.version)
- Codename: $($state.aios.codename)
- Git branch: $($state.git.branch)
- Working tree: $($state.git.working_tree)
- NightWatch installed: $($state.nightwatch.installed)
- NightWatch state: $($state.nightwatch.state)
- Latest queued bug: $($state.runtime.latest_queued_bug)
- Next action: $($state.next_action)
<!-- AIOS_GENERATED_STATUS_END -->
"@

if (-not (Test-Path -LiteralPath $HandoffPath)) {
  Set-Content -LiteralPath $HandoffPath -Value "# AIOS Project Handoff`n`n$statusSection" -Encoding UTF8
} else {
  $handoff = Get-Content -LiteralPath $HandoffPath -Raw -Encoding UTF8
  $pattern = '(?s)<!-- AIOS_GENERATED_STATUS_START -->.*?<!-- AIOS_GENERATED_STATUS_END -->'

  if ($handoff -match $pattern) {
    $handoff = [regex]::Replace($handoff, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $statusSection })
  } else {
    $handoff = $handoff.TrimEnd() + "`r`n`r`n" + $statusSection + "`r`n"
  }

  Set-Content -LiteralPath $HandoffPath -Value $handoff -Encoding UTF8
}

Write-Host "Updated: .aios/runtime/project-state.json" -ForegroundColor Green
Write-Host "Updated: AIOS_HANDOFF.md" -ForegroundColor Green
Write-Host "Version: $($state.aios.version)"
Write-Host "Branch: $($state.git.branch)"
Write-Host "NightWatch: $($state.nightwatch.state)"
Write-Host "Latest queued bug: $($state.runtime.latest_queued_bug)"
Write-Host "Next action: $($state.next_action)"
