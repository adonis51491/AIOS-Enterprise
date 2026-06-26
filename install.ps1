param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath
)

$ErrorActionPreference = "Stop"

$TemplatePath = Join-Path $PSScriptRoot "template\project"
$InstallLog = Join-Path $TargetPath "aios-install.log"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "AIOS Enterprise Installer"
Write-Host "-------------------------"

if (!(Test-Path $TargetPath)) {
    Write-Host "Target path does not exist: $TargetPath"
    exit 1
}

if (!(Test-Path $TemplatePath)) {
    Write-Host "Template path does not exist: $TemplatePath"
    exit 1
}

function Test-CommandExists {
    param([string]$Command)

    $exists = Get-Command $Command -ErrorAction SilentlyContinue
    return $null -ne $exists
}

Write-Host "Checking environment..."

if (Test-CommandExists "git") {
    Write-Host "Git: OK"
} else {
    Write-Host "Git: Not found"
}

if (Test-CommandExists "node") {
    Write-Host "Node: OK"
} else {
    Write-Host "Node: Not found"
}

if (Test-CommandExists "npm") {
    Write-Host "npm: OK"
} else {
    Write-Host "npm: Not found"
}

$ExistingAI = Join-Path $TargetPath ".ai"

if (Test-Path $ExistingAI) {
    $BackupPath = Join-Path $TargetPath ".ai.backup.$Timestamp"
    Write-Host "Existing .ai found. Creating backup: $BackupPath"
    Copy-Item -Path $ExistingAI -Destination $BackupPath -Recurse -Force
}

Write-Host "Installing AIOS Enterprise..."
Write-Host "Target: $TargetPath"
Write-Host "Template: $TemplatePath"

Copy-Item -Path "$TemplatePath\*" -Destination $TargetPath -Recurse -Force

$VersionPath = Join-Path $PSScriptRoot "version.json"
$InstalledVersionPath = Join-Path $TargetPath ".aios-version.json"

if (Test-Path $VersionPath) {
    Copy-Item -Path $VersionPath -Destination $InstalledVersionPath -Force
}

$LogContent = @"
AIOS Enterprise installed successfully.

Installed At:
$Timestamp

Target:
$TargetPath

Template:
$TemplatePath
"@

$LogContent | Out-File -FilePath $InstallLog -Encoding utf8

Write-Host "AIOS Enterprise installed successfully."
Write-Host "Install log: $InstallLog"