[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AIOSRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetProject
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AIOSRoot = [System.IO.Path]::GetFullPath($AIOSRoot)
$TargetProject = [System.IO.Path]::GetFullPath($TargetProject)

if (-not (Test-Path -LiteralPath $AIOSRoot)) {
    throw "AIOSRoot not found: $AIOSRoot"
}
if (-not (Test-Path -LiteralPath $TargetProject)) {
    throw "TargetProject not found: $TargetProject"
}

& (Join-Path $AIOSRoot "doctor.ps1") -Root $AIOSRoot -RequireSourceFiles
if ($LASTEXITCODE -ne 0) {
    throw "AIOS source failed doctor; deployment aborted."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $TargetProject ".aios-backups"
$backup = Join-Path $backupRoot $stamp
New-Item -ItemType Directory -Path $backup -Force | Out-Null

$runtimeFiles = @(
    "AGENTS.md",
    "AIOS_START.md",
    "doctor.ps1",
    ".aios\version.json",
    ".aios\runtime\runtime.json",
    ".aios\workflows\semi-auto-fix.yaml",
    ".aios\policies\semi-auto-fix.yaml",
    ".aios\prompts\AUTO_FIX.md",
    ".aios\prompts\AUTO_FIX_APPROVED.md",
    "scripts\aios-v10.ps1",
    "docs\auto-queue.md",
    "docs\auto-run.md"
)

foreach ($item in $runtimeFiles) {
    $existing = Join-Path $TargetProject $item
    if (Test-Path -LiteralPath $existing) {
        $backupPath = Join-Path $backup $item
        $backupParent = Split-Path -Parent $backupPath
        if (-not (Test-Path -LiteralPath $backupParent)) {
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $existing -Destination $backupPath -Force
    }
}

foreach ($item in $runtimeFiles) {
    $src = Join-Path $AIOSRoot $item
    $dst = Join-Path $TargetProject $item

    if (-not (Test-Path -LiteralPath $src)) {
        throw "Deployment source missing: $src"
    }

    $dstParent = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstParent)) {
        New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

& (Join-Path $TargetProject "scripts\aios-v10.ps1") doctor -Root $TargetProject
if ($LASTEXITCODE -ne 0) {
    throw "Target doctor failed after deployment. Backup: $backup"
}

Write-Host "Deployed AIOS v10.0.2 to $TargetProject"
Write-Host "Backup: $backup"
Write-Host "Next: run scripts\aios-v10.ps1 queue-status"
