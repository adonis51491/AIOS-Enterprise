param(
  [string]$ProjectRoot = (Get-Location).Path,
  [switch]$Once
)

$ErrorActionPreference = "Stop"

$logPath = Join-Path $ProjectRoot ".aios\logs\console.log"
$queueDir = Join-Path $ProjectRoot ".aios\queue"
$inboxDir = Join-Path $ProjectRoot ".aios\inbox"
$bugsDir = Join-Path $ProjectRoot "docs\bugs"
$acceptanceDir = Join-Path $ProjectRoot "docs\acceptance"
$statePath = Join-Path $ProjectRoot ".aios\runtime\watch-state.json"

foreach ($dir in @($queueDir, $inboxDir, $bugsDir, $acceptanceDir, (Split-Path $statePath -Parent))) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

if (-not (Test-Path $logPath)) {
  Write-Host "No log file: $logPath"
  exit 0
}

$patterns = 'TypeError|ReferenceError|Unhandled|HTTP 500|HTTP 502'
$ignore = 'NightWatch clean test|synthetic test'
$lines = Get-Content -LiteralPath $logPath -Encoding UTF8
$match = $lines | Where-Object { $_ -match $patterns -and $_ -notmatch $ignore } | Select-Object -Last 1

if (-not $match) {
  Write-Host "NightWatch: no actionable error."
  exit 0
}

$sha = [System.Security.Cryptography.SHA256]::Create()
$fingerprint = ([BitConverter]::ToString(
  $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($match))
)).Replace("-", "").Substring(0, 16)

$existing = Get-ChildItem -LiteralPath $queueDir -Filter "*.json" -ErrorAction SilentlyContinue |
  ForEach-Object {
    try { Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
  } | Where-Object { $_.fingerprint -eq $fingerprint } | Select-Object -First 1

if ($existing) {
  Write-Host "NightWatch: duplicate suppressed ($fingerprint)." -ForegroundColor Yellow
  exit 0
}

$id = "BUG-AUTO-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$queue = [ordered]@{
  bug_id = $id
  fingerprint = $fingerprint
  status = "queued"
  source_log = ".aios/logs/console.log"
  matched_line = $match
  created_at = (Get-Date -Format "o")
}
$queue | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $queueDir "$id.json") -Encoding UTF8

@"
# $id

## Evidence

- Fingerprint: $fingerprint
- Log: $match

## Status

OPEN
"@ | Set-Content -LiteralPath (Join-Path $bugsDir "$id.md") -Encoding UTF8

@"
# Acceptance Criteria: $id

- [ ] Root cause is identified.
- [ ] The captured error no longer reproduces.
- [ ] Relevant validation is recorded.
- [ ] No unrelated files are modified.
"@ | Set-Content -LiteralPath (Join-Path $acceptanceDir "$id.md") -Encoding UTF8

@"
Follow AIOS Enterprise.

Process queued bug: $id

Read:
- docs/bugs/$id.md
- docs/acceptance/$id.md
- .aios/logs/console.log

PLAN only. Do not edit code. Stop after PLAN.
"@ | Set-Content -LiteralPath (Join-Path $inboxDir "$id-PROMPT.md") -Encoding UTF8

$state = [ordered]@{
  schema_version = 1
  enabled = $true
  last_scan_at = (Get-Date -Format "o")
  last_fingerprint = $fingerprint
  status = "running"
}
$state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8

Write-Host "NightWatch queued: $id" -ForegroundColor Green
