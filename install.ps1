[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AIOSRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SourceRoot = $PSScriptRoot
$AIOSRoot = [System.IO.Path]::GetFullPath($AIOSRoot)

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "Installer source not found: $SourceRoot"
}

if (-not (Test-Path -LiteralPath $AIOSRoot)) {
    New-Item -ItemType Directory -Path $AIOSRoot -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$AIOSRoot.backup.$stamp"

if ((Get-ChildItem -LiteralPath $AIOSRoot -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
    Copy-Item -LiteralPath $AIOSRoot -Destination $backup -Recurse -Force
    Write-Host "Backup: $backup"
}

$items = @(
    "AGENTS.md",
    "README.md",
    "CHANGELOG.md",
    "version.json",
    "install.ps1",
    "deploy.ps1",
    "doctor.ps1",
    ".aios",
    "scripts",
    "templates",
    "docs"
)

foreach ($item in $items) {
    $src = Join-Path -Path $SourceRoot -ChildPath $item
    $dst = Join-Path -Path $AIOSRoot -ChildPath $item

    if (-not (Test-Path -LiteralPath $src)) {
        throw "Required package item missing: $src"
    }

    if ((Get-Item -LiteralPath $src).PSIsContainer) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

& (Join-Path $AIOSRoot "doctor.ps1") -Root $AIOSRoot
if ($LASTEXITCODE -ne 0) {
    throw "Doctor failed after installation."
}

Write-Host "Installed AIOS v10.0.2 to $AIOSRoot"
