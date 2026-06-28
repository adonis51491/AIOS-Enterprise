param(
  [Parameter(Position=0)]
  [ValidateSet('plan','implement','validate','pr','status')]
  [string]$Command = 'status'
)

$ErrorActionPreference = 'Stop'
$Root = (Get-Location).Path
$PromptDir = Join-Path $Root '.aios\prompts'
$ReportsDir = Join-Path $Root '.aios\reports'
$QueueDir = Join-Path $Root '.aios\queue'
New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null

function Get-LatestQueueItem {
  if (-not (Test-Path $QueueDir)) { return $null }
  return Get-ChildItem $QueueDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-BugIdFromQueue($QueueItem) {
  if ($null -eq $QueueItem) { return $null }
  $name = [System.IO.Path]::GetFileNameWithoutExtension($QueueItem.Name)
  return $name
}

function Write-PlanPrompt {
  $queue = Get-LatestQueueItem
  $bugId = Get-BugIdFromQueue $queue
  $out = Join-Path $ReportsDir 'AUTO_FIX_PLAN_PROMPT.md'
  $template = Join-Path $PromptDir 'AUTO_FIX.md'
  if (-not (Test-Path $template)) { throw "Missing prompt: $template" }
  $content = Get-Content $template -Raw -Encoding UTF8
  $header = "# Generated AUTO FIX PLAN`n`nGenerated: $(Get-Date -Format s)`nLatest Queue: $($queue.Name)`nBug ID: $bugId`n`n---`n`n"
  Set-Content -Path $out -Encoding UTF8 -Value ($header + $content)
  Write-Host "Generated: $out"
  Write-Host "Paste this into Codex: AIOS SEMI-AUTO PLAN"
}

function Write-ImplementPrompt {
  $out = Join-Path $ReportsDir 'AUTO_FIX_IMPLEMENT_PROMPT.md'
  $template = Join-Path $PromptDir 'AUTO_FIX_APPROVED.md'
  if (-not (Test-Path $template)) { throw "Missing prompt: $template" }
  Copy-Item $template $out -Force
  Write-Host "Generated: $out"
  Write-Host "Paste this into Codex after typing APPROVED."
}

function Run-Validate {
  npm.cmd run build
  git diff --check
}

function Show-Status {
  Write-Host "AIOS Semi-Auto Fix v9.2.1"
  git branch --show-current
  git status --short
  $queue = Get-LatestQueueItem
  if ($queue) { Write-Host "Latest queue: $($queue.Name)" } else { Write-Host "Latest queue: none" }
}

switch ($Command) {
  'plan' { Write-PlanPrompt }
  'implement' { Write-ImplementPrompt }
  'validate' { Run-Validate }
  'pr' { Write-Host 'Create PR with GitHub CLI manually: gh pr create --base main --head <branch> --title "fix: ..." --body-file .aios/reports/PR_BODY.md' }
  'status' { Show-Status }
}
