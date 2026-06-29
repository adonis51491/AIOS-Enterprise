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
$CreatedProjects = New-Object System.Collections.Generic.List[string]

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-AutoProject([string]$Name, [string]$TaskId = "CONTEST-001") {
    $project = Join-Path $env:TEMP ("aios-auto-run-$Name-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    $CreatedProjects.Add($project) | Out-Null
    [System.IO.File]::WriteAllLines((Join-Path $project "STATUS.md"), @(
        "# STATUS",
        "",
        "## Current Sprint",
        "",
        "* [ ] $TaskId$Colon Fixture repair task",
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
function Write-State([string]$ProjectRoot, $State) {
    $path = Join-Path $ProjectRoot ".aios\runtime\auto-run-state.json"
    $parent = Split-Path -Parent $path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [System.IO.File]::WriteAllText($path, (($State | ConvertTo-Json -Depth 20) + [Environment]::NewLine), $Utf8NoBom)
}

function Remove-TestProject([string]$ProjectRoot) {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { return }
    $tempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
    $fullPath = [System.IO.Path]::GetFullPath($ProjectRoot)
    if ($fullPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fullPath)) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
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


$tests += [pscustomobject]@{
    Name = "auto-run state contract uses task.id and resumes from same state"
    Run = {
        $project = New-AutoProject "state-contract" "CONTEST-900"
        $result = Invoke-AIOS $project @("auto-run")
        Assert-True ($result.ExitCode -eq 0) $result.Output
        $statePath = Join-Path $project ".aios\runtime\auto-run-state.json"
        $raw = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
        $parsed = $raw | ConvertFrom-Json
        Assert-True (($parsed.PSObject.Properties.Name -contains "task")) "State is missing task object"
        Assert-True (($parsed.task.PSObject.Properties.Name -contains "id")) "State is missing task.id"
        Assert-True ($parsed.task.id -eq "CONTEST-900") "Expected CONTEST-900, got $($parsed.task.id)"
        Assert-True (($parsed.PSObject.Properties.Name -notcontains "taskId")) "Producer must not write root taskId"
        Assert-True ($parsed.phase -eq "IMPLEMENT") "Expected IMPLEMENT phase, got $($parsed.phase)"
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -eq 0) $status.Output
        Assert-True ($status.Output -match '"id"\s*:\s*"CONTEST-900"') $status.Output
        $resume = Invoke-AIOS $project @("auto-resume", "-DryRun")
        Assert-True ($resume.ExitCode -eq 0) $resume.Output
        $resumed = Read-State $project
        Assert-True ($resumed.task.id -eq "CONTEST-900") "Runtime did not recover task.id from state"
        Assert-True ($resumed.phase -eq "READY_FOR_REVIEW") "Expected READY_FOR_REVIEW, got $($resumed.phase)"
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state contract rejects empty task id"
    Run = {
        $project = New-AutoProject "empty-task-id" "CONTEST-900"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "IMPLEMENT"
            task = [ordered]@{ id = "" }
            branch = "fix/CONTEST-900-auto"
            events = @()
        }
        Write-State $project $state
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -ne 0) "auto-status unexpectedly accepted empty task id"
        Assert-True ($status.Output -match "AUTO_RUN_STATE_TASK_ID_EMPTY") $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state reader normalizes legacy root taskId"
    Run = {
        $project = New-AutoProject "legacy-task-id" "CONTEST-900"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "IMPLEMENT"
            taskId = "CONTEST-900"
            branch = "fix/CONTEST-900-auto"
            events = @()
        }
        Write-State $project $state
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -eq 0) $status.Output
        Assert-True ($status.Output -match '"taskId"\s*:\s*"CONTEST-900"') $status.Output
        Assert-True ($status.Output -match '"task"') $status.Output
        Assert-True ($status.Output -match '"id"\s*:\s*"CONTEST-900"') $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run test fixture cleanup removes temp project"
    Run = {
        $project = New-AutoProject "cleanup" "CONTEST-900"
        Assert-True (Test-Path -LiteralPath $project) "Fixture was not created"
        Remove-TestProject $project
        Assert-True (-not (Test-Path -LiteralPath $project)) "Fixture was not cleaned"
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state reader prefers canonical task.id over legacy taskId"
    Run = {
        $project = New-AutoProject "canonical-priority" "CONTEST-900"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "IMPLEMENT"
            task = [ordered]@{ id = "CONTEST-900" }
            taskId = "BUG-999"
            branch = "fix/CONTEST-900-auto"
            events = @()
        }
        Write-State $project $state
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -eq 0) $status.Output
        Assert-True ($status.Output -match '"id"\s*:\s*"CONTEST-900"') $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state reader rejects empty state with schema error"
    Run = {
        $project = New-AutoProject "empty-state" "CONTEST-900"
        Write-State $project ([pscustomobject]@{})
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -ne 0) "auto-status unexpectedly accepted empty state"
        Assert-True ($status.Output -match "AUTO_RUN_STATE_PHASE_EMPTY") $status.Output
        Assert-True ($status.Output -notmatch "PropertyNotFoundStrict") $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state reader rejects null state with schema error"
    Run = {
        $project = New-AutoProject "null-state" "CONTEST-900"
        Write-State $project $null
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -ne 0) "auto-status unexpectedly accepted null state"
        Assert-True ($status.Output -match "AUTO_RUN_STATE_EMPTY") $status.Output
        Assert-True ($status.Output -notmatch "PropertyNotFoundStrict") $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state reader rejects null task with schema error"
    Run = {
        $project = New-AutoProject "null-task" "CONTEST-900"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "IMPLEMENT"
            task = $null
            branch = "fix/CONTEST-900-auto"
            events = @()
        }
        Write-State $project $state
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -ne 0) "auto-status unexpectedly accepted null task"
        Assert-True ($status.Output -match "AUTO_RUN_STATE_TASK_ID_EMPTY") $status.Output
        Assert-True ($status.Output -notmatch "PropertyNotFoundStrict") $status.Output
    }
}

$tests += [pscustomobject]@{
    Name = "auto-run state reader rejects malformed task object with schema error"
    Run = {
        $project = New-AutoProject "malformed-task" "CONTEST-900"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "IMPLEMENT"
            task = [ordered]@{}
            branch = "fix/CONTEST-900-auto"
            events = @()
            unrelated = "kept"
        }
        Write-State $project $state
        $status = Invoke-AIOS $project @("auto-status")
        Assert-True ($status.ExitCode -ne 0) "auto-status unexpectedly accepted missing task.id"
        Assert-True ($status.Output -match "AUTO_RUN_STATE_TASK_ID_EMPTY") $status.Output
        Assert-True ($status.Output -notmatch "PropertyNotFoundStrict") $status.Output
    }
}
try {
    foreach ($test in $tests) {
        Write-Host "[TEST] $($test.Name)"
        & $test.Run
        Write-Host "[PASS] $($test.Name)"
    }
}
finally {
    foreach ($project in @($CreatedProjects)) {
        Remove-TestProject $project
    }
}

foreach ($project in @($CreatedProjects)) {
    Assert-True (-not (Test-Path -LiteralPath $project)) "Fixture was not cleaned: $project"
}

Write-Host "All auto-run runtime tests passed."