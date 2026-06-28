[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("help", "doctor", "plan", "approved")]
    [string]$Command = "help",

    [string]$Root = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = [System.IO.Path]::GetFullPath($Root)

function Resolve-AIOSPath([string]$Relative) {
    return Join-Path -Path $Root -ChildPath $Relative
}

function Invoke-Doctor {
    $required = @(
        ".aios\version.json",
        ".aios\runtime\runtime.json",
        ".aios\workflows\semi-auto-fix.yaml",
        ".aios\policies\semi-auto-fix.yaml",
        ".aios\prompts\AUTO_FIX.md",
        ".aios\prompts\AUTO_FIX_APPROVED.md",
        "AGENTS.md"
    )
    $missing = @()
    foreach ($relative in $required) {
        if (Test-Path -LiteralPath (Resolve-AIOSPath $relative)) {
            Write-Host "[OK] $relative"
        }
        else {
            Write-Host "[MISSING] $relative"
            $missing += $relative
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host "AIOS doctor failed. Missing $($missing.Count) file(s)."
        exit 1
    }
    Write-Host "AIOS doctor completed: HEALTHY"
}

switch ($Command) {
    "doctor"   { Invoke-Doctor }
    "plan"     { Get-Content -LiteralPath (Resolve-AIOSPath ".aios\prompts\AUTO_FIX.md") -Encoding UTF8 }
    "approved" { Get-Content -LiteralPath (Resolve-AIOSPath ".aios\prompts\AUTO_FIX_APPROVED.md") -Encoding UTF8 }
    default {
        Write-Host "AIOS v10.0.2 commands:"
        Write-Host "  doctor"
        Write-Host "  plan"
        Write-Host "  approved"
    }
}
