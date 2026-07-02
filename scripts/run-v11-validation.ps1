[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = [System.IO.Path]::GetFullPath($Root)

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "=== $Name ==="
    & $Action
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
    Write-Host "[PASS] $Name"
}

Write-Host "AIOS v11 validation runner"
Write-Host "Root: $Root"
Write-Host "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7 or later is required. Launch this script with pwsh."
}

Push-Location $Root
try {
    Invoke-Step "Git repository check" {
        git rev-parse --is-inside-work-tree | Out-Null
    }

    $branch = (git branch --show-current).Trim()
    if ($branch -ne "feat/aios-v11-governed-orchestrator") {
        throw "Wrong branch: $branch. Expected feat/aios-v11-governed-orchestrator"
    }

    Invoke-Step "AIOS v11 runtime tests" {
        & pwsh -NoProfile -File (Join-Path $Root "tests\aios-v11-runtime.tests.ps1") -AIOSRoot $Root
    }

    Invoke-Step "AIOS v11 doctor" {
        & pwsh -NoProfile -File (Join-Path $Root "scripts\aios-v11.ps1") doctor -Root $Root
    }

    Invoke-Step "JSON parse" {
        Get-Content (Join-Path $Root ".aios\version.json") -Raw | ConvertFrom-Json | Out-Null
        Get-Content (Join-Path $Root ".aios\v11\task.schema.json") -Raw | ConvertFrom-Json | Out-Null
    }

    Invoke-Step "Git diff check" {
        git diff --check main...HEAD
    }

    Write-Host ""
    Write-Host "ALL AIOS V11 VALIDATION CHECKS PASSED"
}
finally {
    Pop-Location
}
