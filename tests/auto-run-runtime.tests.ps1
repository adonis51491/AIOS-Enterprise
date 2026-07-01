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

$tests += [pscustomobject]@{
    Name = "complete-current finalizes matching active auto-run state"
    Run = {
        $project = New-AutoProject "complete-finalizes" "BUG-002"
        Assert-True ((Invoke-AIOS $project @("auto-run")).ExitCode -eq 0) "auto-run failed"
        $complete = Invoke-AIOS $project @("complete-current")
        Assert-True ($complete.ExitCode -eq 0) $complete.Output
        $state = Read-State $project
        Assert-True ($state.phase -eq "COMPLETED") "Expected COMPLETED, got $($state.phase)"
        Assert-True ($state.active -eq $false) "Completed state must be inactive"
        Assert-True ($state.task.id -eq "BUG-002") "Wrong task id"
        Assert-True ($state.task.status -eq "completed") "Task status was not completed"
        Assert-True (-not [string]::IsNullOrWhiteSpace($state.completedAt)) "completedAt missing"
        Assert-True ($state.stopReason -eq "TASK_COMPLETED") "Wrong stopReason"
        Assert-True (@(@($state.events) | Where-Object { $_.phase -eq "COMPLETED" }).Count -eq 1) "Expected one COMPLETED event"
    }
}

$tests += [pscustomobject]@{
    Name = "completed terminal state does not block next BUG-001 dry-run"
    Run = {
        $project = New-AutoProject "completed-allows-next" "BUG-002"
        New-Item -ItemType Directory -Path (Join-Path $project ".aios\queue") -Force | Out-Null
        $queue = [ordered]@{
            id = "BUG-001"
            status = "queued"
            createdAt = (Get-Date).ToString("o")
            source = [ordered]@{ file = "STATUS.md"; line = 6; text = "* [ ] BUG-001$Colon Next task" }
            files = [ordered]@{ bug = "docs/bugs/BUG-001.md"; acceptance = "docs/acceptance/BUG-001.md"; queue = ".aios/queue/BUG-001.json"; inbox = ".aios/inbox/BUG-001-PROMPT.md" }
        }
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\queue\BUG-001.json"), (($queue | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $Utf8NoBom)
        $state = [ordered]@{
            schemaVersion = "10.0.2"
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "COMPLETED"
            active = $false
            dryRun = $false
            task = [ordered]@{ id = "BUG-002"; status = "completed" }
            branch = "fix/BUG-002-auto"
            completedAt = "2026-07-01T00:00:00.0000000Z"
            stopReason = "TASK_COMPLETED"
            events = @([ordered]@{ at = "2026-07-01T00:00:00.0000000Z"; phase = "COMPLETED"; type = "COMPLETED"; message = "done" })
        }
        Write-State $project $state
        $run = Invoke-AIOS $project @("auto-run", "-DryRun")
        Assert-True ($run.ExitCode -eq 0) $run.Output
        $next = Read-State $project
        Assert-True ($next.task.id -eq "BUG-001") "Expected BUG-001, got $($next.task.id)"
        Assert-True ($next.dryRun -eq $true) "Expected dry-run state"
    }
}

$tests += [pscustomobject]@{
    Name = "active auto-run phases block another auto-run"
    Run = {
        foreach ($phase in @("PLAN", "IMPLEMENT", "READY_FOR_REVIEW")) {
            $project = New-AutoProject "active-$phase" "CONTEST-001"
            $state = [ordered]@{
                version = "10.0.2"
                mode = "full-auto-repair"
                phase = $phase
                active = $true
                task = [ordered]@{ id = "CONTEST-001" }
                branch = "fix/CONTEST-001-auto"
                events = @()
            }
            Write-State $project $state
            $run = Invoke-AIOS $project @("auto-run", "-DryRun")
            Assert-True ($run.ExitCode -ne 0) "auto-run unexpectedly ignored active $phase state"
            Assert-True ($run.Output -match "An auto-run is already active: CONTEST-001") $run.Output
        }
    }
}

$tests += [pscustomobject]@{
    Name = "terminal failed stopped and blocked states do not block auto-run"
    Run = {
        foreach ($phase in @("FAILED", "STOPPED", "BLOCKED")) {
            $project = New-AutoProject "terminal-$phase" "CONTEST-001"
            $state = [ordered]@{
                version = "10.0.2"
                mode = "full-auto-repair"
                phase = $phase
                active = $false
                task = [ordered]@{ id = "CONTEST-999" }
                branch = "fix/CONTEST-999-auto"
                events = @()
            }
            Write-State $project $state
            $run = Invoke-AIOS $project @("auto-run", "-DryRun")
            Assert-True ($run.ExitCode -eq 0) $run.Output
            $newState = Read-State $project
            Assert-True ($newState.task.id -eq "CONTEST-001") "Expected new task after $phase"
        }
    }
}

$tests += [pscustomobject]@{
    Name = "unknown auto-run phase fails closed"
    Run = {
        $project = New-AutoProject "unknown-phase" "CONTEST-001"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "MYSTERY"
            task = [ordered]@{ id = "CONTEST-001" }
            branch = "fix/CONTEST-001-auto"
            events = @()
        }
        Write-State $project $state
        $run = Invoke-AIOS $project @("auto-run", "-DryRun")
        Assert-True ($run.ExitCode -ne 0) "unknown phase unexpectedly succeeded"
        Assert-True ($run.Output -match "AUTO_RUN_STATE_UNKNOWN_PHASE") $run.Output
    }
}

$tests += [pscustomobject]@{
    Name = "complete-current rejects state task mismatch before queue update"
    Run = {
        $project = New-AutoProject "complete-mismatch" "BUG-001"
        Assert-True ((Invoke-AIOS $project @("enqueue-next")).ExitCode -eq 0) "enqueue failed"
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "PLAN"
            task = [ordered]@{ id = "BUG-002" }
            branch = "fix/BUG-002-auto"
            events = @()
        }
        Write-State $project $state
        $complete = Invoke-AIOS $project @("complete-current")
        Assert-True ($complete.ExitCode -ne 0) "complete-current unexpectedly accepted mismatched state"
        Assert-True ($complete.Output -match "AUTO_RUN_STATE_TASK_MISMATCH") $complete.Output
        $queue = Get-Content -LiteralPath (Join-Path $project ".aios\queue\BUG-001.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($queue.status -eq "queued") "Queue was updated despite state mismatch"
    }
}

$tests += [pscustomobject]@{
    Name = "finalize-completed-state repairs stale completed queue state"
    Run = {
        $project = New-AutoProject "finalize-stale" "BUG-002"
        New-Item -ItemType Directory -Path (Join-Path $project ".aios\queue") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project ".aios\inbox") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project "docs\bugs") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project "docs\acceptance") -Force | Out-Null
        $bug002 = [ordered]@{ id = "BUG-002"; status = "completed"; completedAt = "2026-07-01T00:00:00.0000000Z"; completionEvidence = [ordered]@{ pullRequest = "#21" } }
        $bug001 = [ordered]@{ id = "BUG-001"; status = "queued"; createdAt = "2026-07-01T01:00:00.0000000Z" }
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\queue\BUG-002.json"), (($bug002 | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\queue\BUG-001.json"), (($bug001 | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\queue\CONTEST-005.json"), "blocked queue", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\inbox\CONTEST-005-PROMPT.md"), "blocked inbox", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project "docs\bugs\CONTEST-005.md"), "blocked bug", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project "docs\acceptance\CONTEST-005.md"), "blocked acceptance", $Utf8NoBom)
        $blockedPaths = @(
            (Join-Path $project ".aios\queue\CONTEST-005.json"),
            (Join-Path $project ".aios\inbox\CONTEST-005-PROMPT.md"),
            (Join-Path $project "docs\bugs\CONTEST-005.md"),
            (Join-Path $project "docs\acceptance\CONTEST-005.md")
        )
        $hashBefore = @($blockedPaths | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash })
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "PLAN"
            dryRun = $true
            active = $true
            task = [ordered]@{ id = "BUG-002" }
            branch = "fix/BUG-002-auto"
            events = @([ordered]@{ at = "2026-07-01T00:00:00.0000000Z"; phase = "PLAN"; message = "stale" })
        }
        Write-State $project $state
        $finalize = Invoke-AIOS $project @("finalize-completed-state")
        Assert-True ($finalize.ExitCode -eq 0) $finalize.Output
        $fixed = Read-State $project
        Assert-True ($fixed.phase -eq "COMPLETED") "Expected COMPLETED"
        Assert-True ($fixed.active -eq $false) "Expected inactive"
        Assert-True ($fixed.task.id -eq "BUG-002") "Wrong finalized task"
        Assert-True (@(@($fixed.events) | Where-Object { $_.phase -eq "COMPLETED" }).Count -eq 1) "Expected one completed event"
        $bug001After = Get-Content -LiteralPath (Join-Path $project ".aios\queue\BUG-001.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($bug001After.status -eq "queued") "Recovery modified next queued task"
        $hashAfter = @($blockedPaths | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash })
        Assert-True (($hashBefore -join ",") -eq ($hashAfter -join ",")) "Blocked task artifacts changed"
        $again = Invoke-AIOS $project @("finalize-completed-state")
        Assert-True ($again.ExitCode -eq 0) $again.Output
        $againState = Read-State $project
        Assert-True (@(@($againState.events) | Where-Object { $_.phase -eq "COMPLETED" }).Count -eq 1) "Recovery duplicated completed event"
    }
}

$tests += [pscustomobject]@{
    Name = "complete-current state write failure does not report success"
    Run = {
        $project = New-AutoProject "state-write-failure" "BUG-002"
        Assert-True ((Invoke-AIOS $project @("auto-run")).ExitCode -eq 0) "auto-run failed"
        $oldValue = $env:AIOS_TEST_FAIL_STATE_WRITE
        try {
            $env:AIOS_TEST_FAIL_STATE_WRITE = "1"
            $complete = Invoke-AIOS $project @("complete-current")
        }
        finally {
            if ($null -eq $oldValue) { Remove-Item Env:\AIOS_TEST_FAIL_STATE_WRITE -ErrorAction SilentlyContinue }
            else { $env:AIOS_TEST_FAIL_STATE_WRITE = $oldValue }
        }
        Assert-True ($complete.ExitCode -ne 0) "complete-current unexpectedly reported full success"
        Assert-True ($complete.Output -match "AUTO_RUN_STATE_COMPLETION_PARTIAL_FAILURE") $complete.Output
        $state = Read-State $project
        Assert-True ($state.phase -ne "COMPLETED") "State was replaced despite simulated write failure"
    }
}

$tests += [pscustomobject]@{
    Name = "legacy root taskId can be finalized by complete-current"
    Run = {
        $project = New-AutoProject "legacy-complete" "BUG-002"
        Assert-True ((Invoke-AIOS $project @("enqueue-next")).ExitCode -eq 0) "enqueue failed"
        $queuePath = Join-Path $project ".aios\queue\BUG-002.json"
        $queue = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $queue.status = "active"
        [System.IO.File]::WriteAllText($queuePath, (($queue | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $Utf8NoBom)
        $state = [ordered]@{
            version = "10.0.2"
            mode = "full-auto-repair"
            phase = "PLAN"
            taskId = "BUG-002"
            branch = "fix/BUG-002-auto"
            events = @()
        }
        Write-State $project $state
        $complete = Invoke-AIOS $project @("complete-current")
        Assert-True ($complete.ExitCode -eq 0) $complete.Output
        $completed = Read-State $project
        Assert-True ($completed.task.id -eq "BUG-002") "Legacy taskId was not normalized"
        Assert-True ($completed.phase -eq "COMPLETED") "Legacy state was not finalized"
        $raw = Get-Content -LiteralPath (Join-Path $project ".aios\runtime\auto-run-state.json") -Raw -Encoding UTF8
        Assert-True ($raw -match '"task"') "Canonical producer did not write task object"
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