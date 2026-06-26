param(
    [Parameter(Mandatory=$true)]
    [string]$Command,

    [string]$TargetPath = "."
)

$Root = $PSScriptRoot

switch ($Command) {
    "version" {
        Get-Content "$Root\version.json"
    }

    "install" {
        & "$Root\install.ps1" -TargetPath $TargetPath
    }

    "doctor" {
        Write-Host "AIOS Doctor"
        Write-Host "-----------"

        git --version
        node --version
        npm --version

        if (Test-Path "$TargetPath\.ai") {
            Write-Host ".ai: OK"
        } else {
            Write-Host ".ai: Missing"
        }

        if (Test-Path "$TargetPath\.github") {
            Write-Host ".github: OK"
        } else {
            Write-Host ".github: Missing"
        }

        if (Test-Path "$TargetPath\package.json") {
            Write-Host "package.json: OK"
        } else {
            Write-Host "package.json: Missing"
        }
    }

    "start" {
        Write-Host "Read this prompt in your AI tool:"
        Write-Host ""
        Get-Content "$Root\template\project\.ai\06_PROMPTS\ENTERPRISE_V6_START.md"
    }

    default {
        Write-Host "Unknown command: $Command"
        Write-Host "Available: version, install, doctor, start"
    }
}