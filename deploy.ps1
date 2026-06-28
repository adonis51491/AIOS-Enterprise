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

& (Join-Path $AIOSRoot "doctor.ps1") -Root $AIOSRoot
if ($LASTEXITCODE -ne 0) {
    throw "AIOS source failed doctor; deployment aborted."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $TargetProject ".aios-backups"
$backup = Join-Path $backupRoot $stamp
New-Item -ItemType Directory -Path $backup -Force | Out-Null

$projectItems = @("AGENTS.md", ".aios", "scripts", "templates", "docs")
foreach ($item in $projectItems) {
    $existing = Join-Path $TargetProject $item
    if (Test-Path -LiteralPath $existing) {
        Copy-Item -LiteralPath $existing -Destination (Join-Path $backup $item) -Recurse -Force
    }
}

foreach ($item in $projectItems) {
    $src = Join-Path $AIOSRoot $item
    $dst = Join-Path $TargetProject $item

    if (-not (Test-Path -LiteralPath $src)) {
        throw "Deployment source missing: $src"
    }

    if ((Get-Item -LiteralPath $src).PSIsContainer) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

& (Join-Path $TargetProject "scripts\aios-v10.ps1") doctor -Root $TargetProject
if ($LASTEXITCODE -ne 0) {
    throw "Target doctor failed after deployment. Backup: $backup"
}

Write-Host "Deployed AIOS v10.0.2 to $TargetProject"
Write-Host "Backup: $backup"
Write-Host "Next: run scripts\aios-v10.ps1 plan"
