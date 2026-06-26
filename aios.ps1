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
    "release" {
    $VersionPath = Join-Path $Root "version.json"
    $ChangelogPath = Join-Path $Root "CHANGELOG.md"
    $ReleaseNotePath = Join-Path $Root "RELEASE_NOTE.md"

    $Current = Get-Content $VersionPath -Raw | ConvertFrom-Json
    $CurrentVersion = $Current.version

    Write-Host "AIOS Release Engine v7"
    Write-Host "Current version: $CurrentVersion"

    $GitSummary = git log -10 --pretty=format:"%s"

    $ReleaseType = "patch"

    if ($GitSummary -match "BREAKING CHANGE|major") {
        $ReleaseType = "major"
    }
    elseif ($GitSummary -match "^feat| feat") {
        $ReleaseType = "minor"
    }
    elseif ($GitSummary -match "^fix| fix|^chore| chore|^docs| docs") {
        $ReleaseType = "patch"
    }

    $Parts = $CurrentVersion.Split(".")
    $Major = [int]$Parts[0]
    $Minor = [int]$Parts[1]
    $Patch = [int]$Parts[2]

    if ($ReleaseType -eq "major") {
        $Major += 1
        $Minor = 0
        $Patch = 0
        $Codename = "Enterprise Runtime"
    }
    elseif ($ReleaseType -eq "minor") {
        $Minor += 1
        $Patch = 0
        $Codename = "Runtime Intelligence"
    }
    else {
        $Patch += 1
        $Codename = "Maintenance Release"
    }

    $NewVersion = "$Major.$Minor.$Patch"
    $Date = Get-Date -Format "yyyy-MM-dd"

    $Summary = "Automated release generated from recent Git commits."

    Write-Host ""
    Write-Host "Detected release type: $ReleaseType"
    Write-Host "Next version: $NewVersion"
    Write-Host "Codename: $Codename"
    Write-Host ""

    $VersionJson = @{
        name = "AIOS Enterprise"
        version = $NewVersion
        codename = $Codename
        description = "AIOS Enterprise $NewVersion - $Codename"
    } | ConvertTo-Json -Depth 3

    $VersionJson | Out-File -FilePath $VersionPath -Encoding utf8

    $Entry = @"
## v$NewVersion

Date: $Date

Codename: $Codename

### Summary

$Summary

### Recent Changes

$GitSummary

---
"@

    $Old = ""
    if (Test-Path $ChangelogPath) {
        $Old = Get-Content $ChangelogPath -Raw
    }

    ($Entry + "`n" + $Old) | Out-File -FilePath $ChangelogPath -Encoding utf8

    $ReleaseNote = @"
# AIOS Enterprise v$NewVersion

Date: $Date

Codename: $Codename

## Summary

$Summary

## Recent Changes

$GitSummary
"@

    $ReleaseNote | Out-File -FilePath $ReleaseNotePath -Encoding utf8

    Write-Host "Updated:"
    Write-Host "- version.json"
    Write-Host "- CHANGELOG.md"
    Write-Host "- RELEASE_NOTE.md"
}
}