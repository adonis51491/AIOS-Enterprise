param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath
)

$TemplatePath = Join-Path $PSScriptRoot "template\project"

if (!(Test-Path $TargetPath)) {
    Write-Host "Target path does not exist: $TargetPath"
    exit 1
}

if (!(Test-Path $TemplatePath)) {
    Write-Host "Template path does not exist: $TemplatePath"
    exit 1
}

Write-Host "Installing AIOS Enterprise..."
Write-Host "Target: $TargetPath"

Copy-Item -Path "$TemplatePath\*" -Destination $TargetPath -Recurse -Force

Write-Host "AIOS Enterprise installed successfully."