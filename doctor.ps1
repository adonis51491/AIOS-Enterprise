[CmdletBinding()]
param(
    [string]$Root,
    [switch]$RequireSourceFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Parent $PSCommandPath

    if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
        throw "Unable to determine the doctor script directory."
    }

    $Root = $scriptDirectory
}

$Root = (Resolve-Path $Root).Path
$Missing = @()

$Required = @(
    ".aios\version.json",
    ".aios\runtime\runtime.json",
    ".aios\workflows\semi-auto-fix.yaml",
    ".aios\policies\semi-auto-fix.yaml",
    ".aios\prompts\AUTO_FIX.md",
    ".aios\prompts\AUTO_FIX_APPROVED.md",
    "scripts\aios-v10.ps1",
    "AGENTS.md",
    "AIOS_START.md",
    "docs\auto-queue.md",
    "docs\auto-run.md"
)

if ($RequireSourceFiles) {
    $Required += @(
        "templates\prompts\AUTO_FIX.md",
        "templates\prompts\AUTO_FIX_APPROVED.md",
        "deploy.ps1"
    )
}

foreach ($relative in $Required) {
    $full = Join-Path -Path $Root -ChildPath $relative
    if (Test-Path -LiteralPath $full) {
        Write-Host "[OK] $relative"
    }
    else {
        Write-Host "[MISSING] $relative"
        $Missing += $relative
    }
}

if ($Missing.Count -gt 0) {
    Write-Host ""
    Write-Host "AIOS doctor failed. Missing $($Missing.Count) file(s)."
    exit 1
}

Write-Host "AIOS doctor completed: HEALTHY"
exit 0
