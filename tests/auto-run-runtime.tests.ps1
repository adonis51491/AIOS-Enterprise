[CmdletBinding()]
param(
    [string]$AIOSRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($AIOSRoot)) {
    $scriptDirectory = Split-Path -Parent $PSCommandPath

    if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
        throw "Unable to determine the test script directory."
    }

    $AIOSRoot = (Resolve-Path (Join-Path $scriptDirectory "..")).Path
}
else {
    $AIOSRoot = (Resolve-Path $AIOSRoot).Path
}

$ScriptPath = Join-Path $AIOSRoot "scripts\aios-v10.ps1"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Colon = [string][char]0xFF1A

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-AutoProject([string]$Name) {
    $project = Join-Path $env:TEMP ("aios-auto-run-$Name-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    [System.IO.File]::WriteAllLines((Join-Path $project "STATUS.md"), @(
        "# STATUS",
        "",
        "## Current Sprint",
        "",
        "* [ ] CONTEST-001$Colon Fixture repair task",
        "* [ ] CONTEST-002$Colon Next task"
    ), $Utf8NoBom)
    Push-Location $project
    try {
        git init -b main | Out-Null
        git config user.email "aios-test@example.com" | Out-Null
        git config user.name "AIOS Test" | Out-Null
        git add STATUS.md | Out-Null
        git commit -m "test fixture" | Out-Null
    }
    finally {
        Pop-Location
    }
    return $project
}

function Invoke-AIOS([string]$ProjectRoot, [string[]]$CommandArgs) {
    Push-Location $ProjectRoot
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @CommandArgs -Root $ProjectRoot *>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    return [pscustomobject]@{ ExitCode = $code; Output = ($output | Out-String) }
}

function Read-State([string]$ProjectRoot) {
    $path = Join-Path $ProjectRoot ".aios\runtime\auto-run-state.json"
    Assert-True (Test-Path -LiteralPath $path) "Missing auto-run state: $path"
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

$tests = @()

$tests += [pscustomobject]@{
    Name = "auto-run creates branch, active queue, and state"
    Run = {
        $project = New-AutoProject "start"
        $result = Invoke-AIOS $project @("auto-run")
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Push-Location $project
        try { $branch = (git branch --show-current).Trim() } finally { Pop-Location }
        Assert-True ($branch -eq "fix/CONTEST-001-auto") "Expected fix branch, got $branch"
        $queue = Get-Content -LiteralPath (Join-Path $project ".aios\queue\CONTEST-001.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($queue.status -eq "active") "Queue was not marked active"
        $state = Read-State $project
        Assert-True ($state.task.id -eq "CONTEST-001") "Wrong state task id"
        Assert-True ($state.branch -eq "fix/CONTEST-001-auto") "Wrong state branch"
        Assert-True ($state.phase -eq "IMPLEMENT") "Expected IMPLEMENT phase, got $($state.phase)"
    }
}

$tests += [pscustomobject]@{
    Name = "auto-status prints persisted state"
    Run = {
        $project = New-AutoProject "status"
        Assert-True ((Invoke-AIOS $project @("auto-run")).ExitCode -eq 0) "auto-run failed"
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -eq 0) $status.Output
        Assert-True ($status.Output -match 'CONTEST-001') $status.Output
        Assert-True ($status.Output -match 'fix/CONTEST-001-auto') $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-resume dry-run reaches ready for review checkpoint"
    Run = {
        $project = New-AutoProject "resume"
        Assert-True ((Invoke-AIOS $project @("auto-run")).ExitCode -eq 0) "auto-run failed"
        $resume = Invoke-AIOS $project @("auto-resume", "-DryRun")
        Assert-True ($resume.ExitCode -eq 0) $resume.Output
        $state = Read-State $project
        Assert-True ($state.phase -eq "READY_FOR_REVIEW") "Expected READY_FOR_REVIEW, got $($state.phase)"
    }
}

$tests += [pscustomobject]@{
    Name = "auto-stop records stopped state"
    Run = {
        $project = New-AutoProject "stop"
        Assert-True ((Invoke-AIOS $project @("auto-run")).ExitCode -eq 0) "auto-run failed"
        $stop = Invoke-AIOS $project @("auto-stop")
        Assert-True ($stop.ExitCode -eq 0) $stop.Output
        $state = Read-State $project
        Assert-True ($state.phase -eq "STOPPED") "Expected STOPPED, got $($state.phase)"
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run refuses protected file changes"
    Run = {
        $project = New-AutoProject "protected"
        [System.IO.File]::WriteAllText((Join-Path $project "package.json"), "{}", $Utf8NoBom)
        $result = Invoke-AIOS $project @("auto-run")
        Assert-True ($result.ExitCode -ne 0) "auto-run unexpectedly succeeded with package.json change"
        Assert-True ($result.Output -match "AUTO_RUN_PROTECTED_FILE_CHANGED|package.json") $result.Output
    }
}

foreach ($test in $tests) {
    Write-Host "[TEST] $($test.Name)"
    & $test.Run
    Write-Host "[PASS] $($test.Name)"
}

Write-Host "All auto-run runtime tests passed."