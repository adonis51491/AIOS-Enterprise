param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath
)

$TemplatePath = Join-Path $PSScriptRoot "template"

if (!(Test-Path $TargetPath)) {
    Write-Host "Target path does not exist: $TargetPath"
    exit 1
}

Write-Host "Installing AIOS Enterprise to $TargetPath"

Copy-Item -Path "$TemplatePath\*" -Destination $TargetPath -Recurse -Force

Write-Host "AIOS Enterprise installed successfully."