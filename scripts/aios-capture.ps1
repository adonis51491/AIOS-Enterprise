param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$Message = "",
  [string]$Source = "manual"
)

$ErrorActionPreference = "Stop"
$logDir = Join-Path $ProjectRoot ".aios\logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logPath = Join-Path $logDir "console.log"

if ([string]::IsNullOrWhiteSpace($Message)) {
  throw "Use -Message to capture a log line."
}

$line = "{0}`t{1}`t{2}" -f (Get-Date -Format "o"), $Source, $Message
Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
Write-Host "Captured: $logPath" -ForegroundColor Green
