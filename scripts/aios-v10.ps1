[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("help", "doctor", "plan", "approved", "enqueue-next", "queue-status", "current", "complete-current", "skip-current", "auto-run", "auto-status", "auto-resume", "auto-stop", "finalize-completed-state")]
    [string]$Command = "help",

    [string]$Root = (Get-Location).Path,

    [switch]$DryRun,

    [int]$CheckTimeoutSeconds = 900,

    [int]$CheckPollSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = [System.IO.Path]::GetFullPath($Root)

function Resolve-AIOSPath([string]$Relative) {
    return Join-Path -Path $Root -ChildPath $Relative
}

function Ensure-AIOSDirectory([string]$Relative) {
    $path = Resolve-AIOSPath $Relative
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Get-QueueFiles {
    $queueRoot = Resolve-AIOSPath ".aios\queue"
    if (-not (Test-Path -LiteralPath $queueRoot)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $queueRoot -Filter "*.json" -File | Sort-Object Name)
}

function Read-QueueFile([System.IO.FileInfo]$File) {
    return Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-CurrentQueueItems {
    $items = @()
    foreach ($file in (Get-QueueFiles)) {
        $item = Read-QueueFile $file
        if ($item.status -in @("queued", "active")) {
            $items += [pscustomobject]@{
                File = $file.FullName
                Item = $item
            }
        }
    }
    return $items
}

function Assert-NoCurrentQueueItem {
    $current = @(Get-CurrentQueueItems)
    if ($current.Count -gt 0) {
        $first = $current[0].Item
        throw "A queued or active AIOS task already exists: $($first.id) [$($first.status)]"
    }
}

function Test-StatusLineCompleted([string]$Line) {
    if ($Line -match "(?i)\[[x]\]") {
        return $true
    }
    return $Line -match "(?i)(^|[^A-Z])(DONE|COMPLETED|CLOSED|SKIPPED)([^A-Z]|$)"
}

function Test-StatusLineUnavailable([string]$Line) {
    if ($Line -match "(?i)\[-\]") {
        return $true
    }
    return $Line -match "(?i)(blocked|dependency[_ -]?blocked)"
}

function Get-StatusSearchRanges([string[]]$Lines) {
    $workOrderHeading = -join ([char[]]@(0x5DE5,0x4F5C,0x9806,0x5E8F))
    $explicitOrderHeading = -join ([char[]]@(0x660E,0x78BA,0x6392,0x5E8F,0x6E05,0x55AE))
    $priorityHeadings = @("Current Sprint", $workOrderHeading, $explicitOrderHeading)
    $ranges = @()

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        foreach ($heading in $priorityHeadings) {
            if ($Lines[$i] -match [regex]::Escape($heading)) {
                $end = $Lines.Count - 1
                for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
                    if ($Lines[$j] -match "^\s{0,3}#{1,6}\s+") {
                        $end = $j - 1
                        break
                    }
                }
                $ranges += [pscustomobject]@{ Start = $i + 1; End = $end }
                break
            }
        }
    }

    if ($ranges.Count -gt 0) {
        return $ranges
    }

    return @([pscustomobject]@{ Start = 0; End = $Lines.Count - 1 })
}

function Get-NextStatusItem {
    $statusPath = Resolve-AIOSPath "STATUS.md"
    if (-not (Test-Path -LiteralPath $statusPath)) {
        throw "STATUS.md not found in target project: $statusPath"
    }

    $lines = @(Get-Content -LiteralPath $statusPath -Encoding UTF8)
    $idPattern = "(?i)\b(CONTEST-\d+|BUG-\d+)\b"
    foreach ($range in (Get-StatusSearchRanges $lines)) {
        for ($i = $range.Start; $i -le $range.End; $i++) {
            $line = $lines[$i]
            $idMatch = [regex]::Match($line, $idPattern)
            if (-not $idMatch.Success) {
                continue
            }
            if (Test-StatusLineCompleted $line) {
                continue
            }
            if (Test-StatusLineUnavailable $line) {
                continue
            }
            return [pscustomobject]@{
                Id = $idMatch.Groups[1].Value.ToUpperInvariant()
                LineNumber = $i + 1
                Text = $line.Trim()
                Raw = $line
            }
        }
    }
    return $null
}

function Write-NewFile([string]$Path, [string]$Content) {
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite existing file: $Path"
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function New-QueueArtifactPlan($SelectedTask) {
    $id = $SelectedTask.Id
    $bugRoot = Ensure-AIOSDirectory "docs\bugs"
    $acceptanceRoot = Ensure-AIOSDirectory "docs\acceptance"
    $queueRoot = Ensure-AIOSDirectory ".aios\queue"
    $inboxRoot = Ensure-AIOSDirectory ".aios\inbox"

    return [ordered]@{
        Id = $id
        BugPath = Join-Path $bugRoot "$id.md"
        AcceptancePath = Join-Path $acceptanceRoot "$id.md"
        QueuePath = Join-Path $queueRoot "$id.json"
        InboxPath = Join-Path $inboxRoot "$id-PROMPT.md"
    }
}

function Assert-NewQueueArtifactTargets($Plan) {
    foreach ($path in @($Plan.BugPath, $Plan.AcceptancePath, $Plan.QueuePath, $Plan.InboxPath)) {
        if (Test-Path -LiteralPath $path) {
            throw "Refusing to overwrite existing file: $path"
        }
    }
}

function Write-QueueArtifactsSafely($Plan, [string]$BugContent, [string]$AcceptanceContent, [string]$InboxContent, $QueueItem) {
    Assert-NewQueueArtifactTargets $Plan

    $json = $QueueItem | ConvertTo-Json -Depth 8
    $artifacts = @(
        [pscustomobject]@{ Path = $Plan.BugPath; Content = $BugContent },
        [pscustomobject]@{ Path = $Plan.AcceptancePath; Content = $AcceptanceContent },
        [pscustomobject]@{ Path = $Plan.InboxPath; Content = $InboxContent },
        [pscustomobject]@{ Path = $Plan.QueuePath; Content = ($json + [Environment]::NewLine) }
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("aios-artifacts-" + [guid]::NewGuid().ToString("N"))
    $createdTargets = @()

    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        for ($i = 0; $i -lt $artifacts.Count; $i++) {
            if ($env:AIOS_TEST_FAIL_AFTER_ARTIFACT_COUNT -and $i -ge [int]$env:AIOS_TEST_FAIL_AFTER_ARTIFACT_COUNT) {
                throw "AIOS_TEST_SIMULATED_ARTIFACT_FAILURE"
            }
            $tempPath = Join-Path $tempRoot "$i.tmp"
            [System.IO.File]::WriteAllText($tempPath, $artifacts[$i].Content, $utf8NoBom)
            Move-Item -LiteralPath $tempPath -Destination $artifacts[$i].Path -ErrorAction Stop
            $createdTargets += $artifacts[$i].Path
        }
    }
    catch {
        foreach ($path in $createdTargets) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force
            }
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Save-QueueItem([string]$Path, $Item) {
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite existing queue file: $Path"
    }
    $json = $Item | ConvertTo-Json -Depth 8
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($json + [Environment]::NewLine), $utf8NoBom)
}

function Update-ExistingQueueItem([string]$Path, $Item) {
    $json = $Item | ConvertTo-Json -Depth 8
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($json + [Environment]::NewLine), $utf8NoBom)
}

function Get-SingleCurrentQueueItem {
    $current = @(Get-CurrentQueueItems)
    if ($current.Count -eq 0) {
        throw "No queued or active AIOS task exists."
    }
    if ($current.Count -gt 1) {
        throw "More than one queued or active AIOS task exists. Resolve the queue before continuing."
    }
    return $current[0]
}

function Update-StatusLine([int]$LineNumber, [string]$State) {
    $statusPath = Resolve-AIOSPath "STATUS.md"
    $lines = @(Get-Content -LiteralPath $statusPath -Encoding UTF8)
    $index = $LineNumber - 1
    if ($index -lt 0 -or $index -ge $lines.Count) {
        throw "STATUS.md line $LineNumber is no longer available."
    }

    if ($lines[$index] -match "^(\s*[-*]\s+)\[[^\]]*\]") {
        $marker = if ($State -eq "completed") { "x" } else { "-" }
        $lines[$index] = [regex]::Replace($lines[$index], "^(\s*[-*]\s+)\[[^\]]*\]", "`${1}[$marker]", 1)
    }
    elseif ($State -eq "completed") {
        $lines[$index] = "$($lines[$index]) - DONE"
    }
    else {
        $lines[$index] = "$($lines[$index]) - SKIPPED"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($statusPath, (($lines -join [Environment]::NewLine) + [Environment]::NewLine), $utf8NoBom)
}


function Get-AutoRunStatePath {
    return Resolve-AIOSPath ".aios\runtime\auto-run-state.json"
}

function New-AutoRunState([string]$Phase) {
    return [ordered]@{
        schemaVersion = "10.0.2"
        version = "10.0.2"
        mode = "full-auto-repair"
        phase = $Phase
        active = $true
        dryRun = [bool]$DryRun
        task = $null
        branch = $null
        pullRequest = $null
        checks = @()
        events = @()
        safety = [ordered]@{
            allowDirectMainEdits = $false
            allowAutoMerge = $false
            protectedFiles = @(".env", ".env.local", "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock")
            blockedPathPatterns = @("^prisma/+/migrations/", "(?i)payment", "(?i)payuni", "(?i)ecpay")
        }
        startedAt = (Get-Date).ToString("o")
        updatedAt = (Get-Date).ToString("o")
    }
}

function Save-AutoRunState($State) {
    $path = Get-AutoRunStatePath
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $State | Add-Member -NotePropertyName updatedAt -NotePropertyValue (Get-Date).ToString("o") -Force
    $json = $State | ConvertTo-Json -Depth 12
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $tempPath = Join-Path $parent ("auto-run-state." + [guid]::NewGuid().ToString("N") + ".tmp")
    try {
        [System.IO.File]::WriteAllText($tempPath, ($json + [Environment]::NewLine), $utf8NoBom)
        if ($env:AIOS_TEST_FAIL_STATE_WRITE -eq "1") {
            throw "AIOS_TEST_SIMULATED_STATE_WRITE_FAILURE"
        }
        if (Test-Path -LiteralPath $path) {
            $backupPath = $tempPath + ".bak"
            [System.IO.File]::Replace($tempPath, $path, $backupPath)
            if (Test-Path -LiteralPath $backupPath) {
                Remove-Item -LiteralPath $backupPath -Force
            }
        }
        else {
            Move-Item -LiteralPath $tempPath -Destination $path
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
}

function Get-SafePropertyValue($Object, [string]$PropertyName) {
    if ($null -eq $Object) { return $null }
    if ([string]::IsNullOrWhiteSpace($PropertyName)) { return $null }
    $psObject = $Object.PSObject
    if ($null -eq $psObject) { return $null }
    $property = $psObject.Properties[$PropertyName]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-AutoRunStateTaskId($State) {
    if ($null -eq $State) { return $null }

    $task = Get-SafePropertyValue $State "task"
    if ($null -ne $task) {
        $canonicalId = Get-SafePropertyValue $task "id"
        if (-not [string]::IsNullOrWhiteSpace($canonicalId)) {
            return [string]$canonicalId
        }
    }

    $legacyId = Get-SafePropertyValue $State "taskId"
    if (-not [string]::IsNullOrWhiteSpace($legacyId)) {
        return [string]$legacyId
    }

    return $null
}

function Normalize-AutoRunState($State) {
    if ($null -eq $State) { return $null }
    $taskId = Get-AutoRunStateTaskId $State
    if ([string]::IsNullOrWhiteSpace($taskId)) { return $State }

    $task = Get-SafePropertyValue $State "task"
    if ($null -eq $task) {
        $task = [pscustomobject]@{}
        $State | Add-Member -NotePropertyName task -NotePropertyValue $task -Force
    }

    $id = Get-SafePropertyValue $task "id"
    if ([string]::IsNullOrWhiteSpace($id)) {
        $task | Add-Member -NotePropertyName id -NotePropertyValue $taskId -Force
    }

    return $State
}

function Assert-AutoRunStateContract($State) {
    if ($null -eq $State) { throw "AUTO_RUN_STATE_EMPTY" }

    $phase = Get-SafePropertyValue $State "phase"
    if ([string]::IsNullOrWhiteSpace($phase)) {
        throw "AUTO_RUN_STATE_PHASE_EMPTY"
    }

    $task = Get-SafePropertyValue $State "task"
    if ($phase -eq "STOPPED" -and $null -eq $task) {
        return
    }

    $taskId = Get-AutoRunStateTaskId $State
    if ([string]::IsNullOrWhiteSpace($taskId)) {
        throw "AUTO_RUN_STATE_TASK_ID_EMPTY"
    }
}

function Get-AutoRunTerminalPhases {
    return @("COMPLETED", "FAILED", "STOPPED", "BLOCKED")
}

function Get-AutoRunActivePhases {
    return @("STARTED", "QUEUED", "BRANCH_READY", "PLAN", "IMPLEMENT", "VALIDATE_BUILD", "VALIDATE_DIFF", "COMMITTED", "PUSHED", "PULL_REQUEST", "WAITING_CHECKS", "READY_FOR_REVIEW")
}

function Test-AutoRunStateIsTerminal($State) {
    if ($null -eq $State) { return $false }
    $phase = [string](Get-SafePropertyValue $State "phase")
    if ([string]::IsNullOrWhiteSpace($phase)) { return $false }
    return (Get-AutoRunTerminalPhases) -contains $phase
}

function Test-AutoRunStateIsActive($State) {
    if ($null -eq $State) { return $false }
    $phase = [string](Get-SafePropertyValue $State "phase")
    if ([string]::IsNullOrWhiteSpace($phase)) { throw "AUTO_RUN_STATE_PHASE_EMPTY" }
    if (Test-AutoRunStateIsTerminal $State) { return $false }
    if ((Get-AutoRunActivePhases) -contains $phase) { return $true }
    throw "AUTO_RUN_STATE_UNKNOWN_PHASE: $phase"
}

function Get-QueueEntryById([string]$TaskId) {
    foreach ($file in (Get-QueueFiles)) {
        $item = Read-QueueFile $file
        if ($item.id -eq $TaskId) {
            return [pscustomobject]@{ File = $file.FullName; Item = $item }
        }
    }
    return $null
}

function Assert-AutoRunStateMatchesTaskForCompletion($State, [string]$TaskId) {
    if ($null -eq $State) { return }
    $stateTaskId = Get-AutoRunStateTaskId $State
    if ($stateTaskId -ne $TaskId) {
        throw "AUTO_RUN_STATE_TASK_MISMATCH: $stateTaskId; expected $TaskId"
    }
}

function Assert-AutoRunStateHasNoUnfinishedSensitiveEvents($State) {
    if ($null -eq $State -or $null -eq $State.events) { return }
    foreach ($event in @($State.events)) {
        $phase = Get-SafePropertyValue $event "phase"
        if ([string]::IsNullOrWhiteSpace($phase)) { $phase = Get-SafePropertyValue $event "type" }
        if ($phase -in @("COMMITTED", "PUSHED", "PULL_REQUEST", "WAITING_CHECKS")) {
            throw "AUTO_RUN_STATE_HAS_UNFINISHED_SENSITIVE_EVENT: $phase"
        }
    }
}

function Complete-AutoRunState($State, [string]$TaskId, [string]$StopReason) {
    if ($null -eq $State) { return $null }
    Assert-AutoRunStateMatchesTaskForCompletion $State $TaskId

    if (Test-AutoRunStateIsTerminal $State) {
        if ($State.phase -eq "COMPLETED") {
            return $State
        }
        throw "AUTO_RUN_STATE_ALREADY_TERMINAL: $($State.phase)"
    }

    $completedAt = (Get-Date).ToUniversalTime().ToString("o")
    $State.phase = "COMPLETED"
    $State | Add-Member -NotePropertyName active -NotePropertyValue $false -Force
    $State | Add-Member -NotePropertyName dryRun -NotePropertyValue $false -Force
    $State | Add-Member -NotePropertyName completedAt -NotePropertyValue $completedAt -Force
    $State | Add-Member -NotePropertyName stopReason -NotePropertyValue $StopReason -Force
    if ($null -ne $State.task) {
        $State.task | Add-Member -NotePropertyName status -NotePropertyValue "completed" -Force
    }

    $alreadyCompleted = $false
    if ($null -ne $State.events) {
        foreach ($event in @($State.events)) {
            $phase = Get-SafePropertyValue $event "phase"
            if ([string]::IsNullOrWhiteSpace($phase)) { $phase = Get-SafePropertyValue $event "type" }
            if ($phase -eq "COMPLETED") { $alreadyCompleted = $true }
        }
    }
    if (-not $alreadyCompleted) {
        $event = [ordered]@{
            at = $completedAt
            phase = "COMPLETED"
            type = "COMPLETED"
            message = "Task $TaskId completed; auto-run state finalized."
        }
        $events = @()
        if ($null -ne $State.events) { $events += @($State.events) }
        $events += [pscustomobject]$event
        $State.events = $events
    }

    Save-AutoRunState $State
    $saved = Read-AutoRunState
    if (-not (Test-AutoRunStateIsTerminal $saved)) {
        throw "AUTO_RUN_STATE_COMPLETION_VERIFY_FAILED"
    }
    Assert-AutoRunStateMatchesTaskForCompletion $saved $TaskId
    return $saved
}

function Read-AutoRunState {
    $path = Get-AutoRunStatePath
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    $state = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $state = Normalize-AutoRunState $state
    Assert-AutoRunStateContract $state
    return $state
}

function Add-AutoRunEvent($State, [string]$Phase, [string]$Message) {
    $event = [ordered]@{
        at = (Get-Date).ToString("o")
        phase = $Phase
        message = $Message
    }
    $events = @()
    if ($null -ne $State.events) {
        $events += @($State.events)
    }
    $events += [pscustomobject]$event
    $State.events = $events
    $State.phase = $Phase
    Save-AutoRunState $State
}

function Invoke-LocalGit([string[]]$Arguments, [switch]$AllowFailure) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed: $($output | Out-String)"
    }
    return [pscustomobject]@{ ExitCode = $code; Output = ($output | Out-String) }
}

function Get-GitBranchName {
    return (Invoke-LocalGit -Arguments @("branch", "--show-current")).Output.Trim()
}

function Get-GitChangedPaths {
    $result = Invoke-LocalGit -Arguments @("status", "--porcelain=v1", "-uall")
    $paths = @()
    foreach ($line in ($result.Output -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $path = $line.Substring(3).Trim()
        if ($path -match " -> ") { $path = ($path -split " -> ")[-1] }
        $paths += ($path -replace "\\", "/")
    }
    return $paths
}


function Assert-NoProtectedAutoRunChanges {
    $protected = @(".env", ".env.local", "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock")
    $blockedPatterns = @("^prisma/+/migrations/", "(?i)payment", "(?i)payuni", "(?i)ecpay")
    foreach ($path in (Get-GitChangedPaths)) {
        $leaf = Split-Path -Leaf $path
        if ($protected -contains $path -or $protected -contains $leaf) {
            throw "AUTO_RUN_PROTECTED_FILE_CHANGED: $path"
        }
        foreach ($pattern in $blockedPatterns) {
            if ($path -match $pattern) {
                throw "AUTO_RUN_BLOCKED_PATH_CHANGED: $path"
            }
        }
    }
}
function Assert-AutoRunSafety([string]$Branch) {
    if ($Branch -eq "main" -or $Branch -eq "master") {
        throw "AUTO_RUN_REFUSED_ON_MAIN"
    }
    $protected = @(".env", ".env.local", "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock")
    $blockedPatterns = @("^prisma/+/migrations/", "(?i)payment", "(?i)payuni", "(?i)ecpay")
    foreach ($path in (Get-GitChangedPaths)) {
        $leaf = Split-Path -Leaf $path
        if ($protected -contains $path -or $protected -contains $leaf) {
            throw "AUTO_RUN_PROTECTED_FILE_CHANGED: $path"
        }
        foreach ($pattern in $blockedPatterns) {
            if ($path -match $pattern) {
                throw "AUTO_RUN_BLOCKED_PATH_CHANGED: $path"
            }
        }
    }
}

function Assert-NoActiveAutoRun {
    $state = Read-AutoRunState
    if ($null -eq $state) { return }
    if (Test-AutoRunStateIsTerminal $state) { return }
    if (Test-AutoRunStateIsActive $state) {
        throw "An auto-run is already active: $(Get-AutoRunStateTaskId $state) [$($state.phase)]"
    }
    throw "AUTO_RUN_STATE_UNKNOWN_PHASE: $($state.phase)"
}

function Get-AutoRunTask {
    $current = @(Get-CurrentQueueItems)
    if ($current.Count -eq 0) {
        Invoke-EnqueueNext
        $current = @(Get-CurrentQueueItems)
    }
    if ($current.Count -eq 0) {
        throw "AUTO_RUN_NO_QUEUED_TASK"
    }
    if ($current.Count -gt 1) {
        throw "AUTO_RUN_MULTIPLE_QUEUED_TASKS"
    }
    return $current[0]
}

function Invoke-AutoStatus {
    $state = Read-AutoRunState
    if ($null -eq $state) {
        Write-Host "AIOS auto-run state: IDLE"
        return
    }
    $state | ConvertTo-Json -Depth 12
}

function Stop-AutoRun {
    $state = Read-AutoRunState
    if ($null -eq $state) {
        $state = New-AutoRunState "STOPPED"
        $state | Add-Member -NotePropertyName active -NotePropertyValue $false -Force
        $state | Add-Member -NotePropertyName stopReason -NotePropertyValue "AUTO_RUN_STOPPED" -Force
        Add-AutoRunEvent $state "STOPPED" "No active auto-run existed."
    }
    else {
        $state | Add-Member -NotePropertyName active -NotePropertyValue $false -Force
        $state | Add-Member -NotePropertyName stoppedAt -NotePropertyValue (Get-Date).ToString("o") -Force
        $state | Add-Member -NotePropertyName stopReason -NotePropertyValue "AUTO_RUN_STOPPED" -Force
        Add-AutoRunEvent $state "STOPPED" "Auto-run stopped by command."
    }
    Write-Host "AIOS auto-run stopped."
}

function Start-AutoRun {
    Assert-NoProtectedAutoRunChanges
    Assert-NoActiveAutoRun
    $taskEntry = Get-AutoRunTask
    $task = $taskEntry.Item
    $taskId = $task.id
    $task.status = "active"
    $task | Add-Member -NotePropertyName activatedAt -NotePropertyValue (Get-Date).ToString("o") -Force
    Update-ExistingQueueItem $taskEntry.File $task
    $branch = "fix/$taskId-auto"
    $state = New-AutoRunState "STARTED"
    $state.task = [ordered]@{
        id = $taskId
        queueFile = $taskEntry.File
        source = $task.source
        files = $task.files
    }
    $state.branch = $branch
    Add-AutoRunEvent $state "QUEUED" "Task $taskId selected from STATUS.md."

    $currentBranch = Get-GitBranchName
    if ($currentBranch -eq "main" -or $currentBranch -eq "master") {
        if ($DryRun) {
            Add-AutoRunEvent $state "BRANCH_READY" "Dry run would create branch $branch."
        }
        else {
            $existing = Invoke-LocalGit -Arguments @("branch", "--list", $branch)
            if ([string]::IsNullOrWhiteSpace($existing.Output)) {
                Invoke-LocalGit -Arguments @("switch", "-c", $branch) | Out-Null
            }
            else {
                Invoke-LocalGit -Arguments @("switch", $branch) | Out-Null
            }
            Add-AutoRunEvent $state "BRANCH_READY" "Branch $branch is active."
        }
    }
    elseif ($currentBranch -ne $branch) {
        throw "AUTO_RUN_UNEXPECTED_BRANCH: $currentBranch; expected main/master or $branch"
    }
    else {
        Add-AutoRunEvent $state "BRANCH_READY" "Already on branch $branch."
    }

    Add-AutoRunEvent $state "PLAN" "PLAN step recorded. Automated implementation must honor AGENTS.md, AIOS_START.md, bug and acceptance docs."
    Add-AutoRunEvent $state "IMPLEMENT" "IMPLEMENT step ready. Run auto-resume after code changes are present."
    Write-Host "AIOS auto-run prepared task $taskId on $branch."
}

function Resume-AutoRun {
    $state = Read-AutoRunState
    if ($null -eq $state) { throw "AUTO_RUN_STATE_NOT_FOUND" }
    if (Test-AutoRunStateIsTerminal $state) { throw "AUTO_RUN_TERMINAL_STATE: $($state.phase)" }
    if ($state.phase -eq "READY_FOR_REVIEW") { Write-Host "AIOS auto-run already ready for review."; return }

    $branch = Get-GitBranchName
    Assert-AutoRunSafety $branch
    if ($branch -ne $state.branch -and -not $DryRun) {
        throw "AUTO_RUN_BRANCH_MISMATCH: $branch; expected $($state.branch)"
    }

    Add-AutoRunEvent $state "VALIDATE_BUILD" "Running npm.cmd run build."
    if (-not $DryRun) {
        $buildOutput = & npm.cmd run build 2>&1
        if ($LASTEXITCODE -ne 0) {
            Add-AutoRunEvent $state "FAILED" "npm.cmd run build failed."
            throw ($buildOutput | Out-String)
        }
    }
    else {
        Add-AutoRunEvent $state "VALIDATE_BUILD" "Dry run skipped npm.cmd run build."
    }

    Add-AutoRunEvent $state "VALIDATE_DIFF" "Running git diff --check."
    Invoke-LocalGit -Arguments @("diff", "--check") | Out-Null

    if (-not $DryRun) {
        Assert-AutoRunSafety $branch
        $changed = @(Get-GitChangedPaths)
        if ($changed.Count -eq 0) {
            Add-AutoRunEvent $state "FAILED" "No changes available to commit."
            throw "AUTO_RUN_NO_CHANGES_TO_COMMIT"
        }
        Invoke-LocalGit -Arguments @("add", "-A") | Out-Null
        Invoke-LocalGit -Arguments @("diff", "--cached", "--check") | Out-Null
        $message = "fix($($state.task.id)): auto repair"
        Invoke-LocalGit -Arguments @("commit", "-m", $message) | Out-Null
        Add-AutoRunEvent $state "COMMITTED" $message
        Invoke-LocalGit -Arguments @("push", "-u", "origin", $state.branch) | Out-Null
        Add-AutoRunEvent $state "PUSHED" "Branch pushed to origin."

        $body = "Automated AIOS repair for $($state.task.id).`n`nHuman merge remains required."
        $prOutput = & gh pr create --draft --base main --head $state.branch --title "fix($($state.task.id)): auto repair" --body $body 2>&1
        if ($LASTEXITCODE -ne 0) {
            Add-AutoRunEvent $state "FAILED" "Draft PR creation failed."
            throw ($prOutput | Out-String)
        }
        $state.pullRequest = [ordered]@{ url = ($prOutput | Select-Object -Last 1); draft = $true }
        Save-AutoRunState $state
        Add-AutoRunEvent $state "PULL_REQUEST" "Draft PR created."

        $deadline = (Get-Date).AddSeconds($CheckTimeoutSeconds)
        do {
            $checks = & gh pr checks $state.pullRequest.url 2>&1
            $state.checks = @($checks)
            Save-AutoRunState $state
            $text = $checks | Out-String
            if ($text -match "fail|cancel|timed_out|action_required") {
                Add-AutoRunEvent $state "FAILED" "GitHub checks failed."
                throw $text
            }
            if ($text -match "pass" -and $text -notmatch "pending|queued|in_progress") { break }
            Start-Sleep -Seconds $CheckPollSeconds
        } while ((Get-Date) -lt $deadline)

        if ((Get-Date) -ge $deadline) {
            Add-AutoRunEvent $state "WAITING_CHECKS" "Checks did not finish before timeout."
            Write-Host "AIOS auto-run waiting for checks."
            return
        }
        & gh pr ready $state.pullRequest.url | Out-Null
        $state.pullRequest.draft = $false
        Save-AutoRunState $state
        Add-AutoRunEvent $state "READY_FOR_REVIEW" "Checks passed and PR marked ready for review. Human merge required."
    }
    else {
        Add-AutoRunEvent $state "READY_FOR_REVIEW" "Dry run completed through ready-for-review checkpoint."
    }
    Write-Host "AIOS auto-run reached READY_FOR_REVIEW. Human merge required."
}
function Invoke-Doctor {
    $required = @(
        ".aios\version.json",
        ".aios\runtime\runtime.json",
        ".aios\workflows\semi-auto-fix.yaml",
        ".aios\policies\semi-auto-fix.yaml",
        ".aios\prompts\AUTO_FIX.md",
        ".aios\prompts\AUTO_FIX_APPROVED.md",
        "AGENTS.md",
        "AIOS_START.md",
        "docs\auto-queue.md",
        "docs\auto-run.md"
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

function Invoke-EnqueueNext {
    Assert-NoCurrentQueueItem
    $selectedTask = Get-NextStatusItem
    if ($null -eq $selectedTask) {
        Write-Host "NO_ELIGIBLE_STATUS_ITEM"
        return
    }

    $id = $selectedTask.Id
    $artifactPlan = New-QueueArtifactPlan $selectedTask
    Assert-NewQueueArtifactTargets $artifactPlan

    $createdAt = (Get-Date).ToString("o")
    $bugContent = @"
# $id

Source: STATUS.md line $($selectedTask.LineNumber)
Status item: $($selectedTask.Text)
Created: $createdAt

## Bug

Implement the queued STATUS.md item without changing unrelated project behavior.

## Scope

- Read AGENTS.md and AIOS_START.md before implementation.
- Read docs/acceptance/$id.md before implementation.
- Follow the PLAN -> APPROVED -> IMPLEMENT -> VALIDATE -> PULL_REQUEST -> HUMAN_MERGE workflow.
- Do not edit protected files without explicit approval.
"@

    $acceptanceContent = @"
# Acceptance: $id

The queued item is accepted when:

- The STATUS.md item is implemented or intentionally resolved.
- Required validation from .aios/runtime/runtime.json passes.
- The working tree contains only intentional changes.
- A pull request is opened and not merged automatically.
"@

    $inboxContent = @"
# AIOS Inbox Prompt: $id

Queued from STATUS.md line $($selectedTask.LineNumber):

> $($selectedTask.Text)

Read before implementation:

- docs/bugs/$id.md
- docs/acceptance/$id.md
- .aios/queue/$id.json

Next command:

````powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 current
````
"@

    $queueItem = [ordered]@{
        id = $id
        status = "queued"
        createdAt = $createdAt
        source = [ordered]@{
            file = "STATUS.md"
            line = $selectedTask.LineNumber
            text = $selectedTask.Text
        }
        files = [ordered]@{
            bug = "docs/bugs/$id.md"
            acceptance = "docs/acceptance/$id.md"
            queue = ".aios/queue/$id.json"
            inbox = ".aios/inbox/$id-PROMPT.md"
        }
    }

    Write-QueueArtifactsSafely $artifactPlan $bugContent $acceptanceContent $inboxContent $queueItem

    Write-Host "Queued $id"
    Write-Host "Bug: $($artifactPlan.BugPath)"
    Write-Host "Acceptance: $($artifactPlan.AcceptancePath)"
    Write-Host "Queue: $($artifactPlan.QueuePath)"
    Write-Host "Inbox: $($artifactPlan.InboxPath)"
}

function Invoke-QueueStatus {
    $files = @(Get-QueueFiles)
    if ($files.Count -eq 0) {
        Write-Host "AIOS queue is empty."
        return
    }
    foreach ($file in $files) {
        $item = Read-QueueFile $file
        Write-Host "$($item.id) [$($item.status)] $($item.source.text)"
    }
}

function Invoke-Current {
    $current = @(Get-CurrentQueueItems)
    if ($current.Count -eq 0) {
        Write-Host "No queued or active AIOS task exists."
        return
    }
    foreach ($entry in $current) {
        $item = $entry.Item
        Write-Host "$($item.id) [$($item.status)]"
        Write-Host "Source: $($item.source.file):$($item.source.line)"
        Write-Host "Item: $($item.source.text)"
        Write-Host "Bug: $($item.files.bug)"
        Write-Host "Acceptance: $($item.files.acceptance)"
        Write-Host "Inbox: $($item.files.inbox)"
    }
}

function Complete-Current {
    $entry = Get-SingleCurrentQueueItem
    $item = $entry.Item
    $state = Read-AutoRunState
    Assert-AutoRunStateMatchesTaskForCompletion $state $item.id

    $item.status = "completed"
    $item | Add-Member -NotePropertyName completedAt -NotePropertyValue (Get-Date).ToString("o") -Force
    Update-ExistingQueueItem $entry.File $item
    Update-StatusLine $item.source.line "completed"

    try {
        Complete-AutoRunState $state $item.id "TASK_COMPLETED" | Out-Null
    }
    catch {
        throw "AUTO_RUN_STATE_COMPLETION_PARTIAL_FAILURE: queue $($item.id) completed but state finalization failed. $($_.Exception.Message)"
    }

    Write-Host "Completed $($item.id)"
}

function Finalize-CompletedState {
    $state = Read-AutoRunState
    if ($null -eq $state) {
        Write-Host "AIOS auto-run state: IDLE"
        return
    }

    $taskId = Get-AutoRunStateTaskId $state
    if (Test-AutoRunStateIsTerminal $state) {
        if ($state.phase -eq "COMPLETED") {
            Write-Host "AIOS auto-run state already completed for $taskId."
            return
        }
        throw "AUTO_RUN_STATE_ALREADY_TERMINAL: $($state.phase)"
    }

    Assert-AutoRunStateHasNoUnfinishedSensitiveEvents $state
    $entry = Get-QueueEntryById $taskId
    if ($null -eq $entry) {
        throw "AUTO_RUN_QUEUE_NOT_FOUND_FOR_STATE: $taskId"
    }
    if ($entry.Item.status -ne "completed") {
        throw "AUTO_RUN_QUEUE_NOT_COMPLETED_FOR_STATE: $taskId [$($entry.Item.status)]"
    }
    $completedAt = Get-SafePropertyValue $entry.Item "completedAt"
    if ([string]::IsNullOrWhiteSpace($completedAt)) {
        throw "AUTO_RUN_QUEUE_COMPLETION_METADATA_MISSING: $taskId"
    }

    Complete-AutoRunState $state $taskId "TASK_COMPLETED" | Out-Null
    Write-Host "Finalized completed auto-run state for $taskId."
}

function Skip-Current {
    $entry = Get-SingleCurrentQueueItem
    $item = $entry.Item
    $item.status = "skipped"
    $item | Add-Member -NotePropertyName skippedAt -NotePropertyValue (Get-Date).ToString("o") -Force
    Update-ExistingQueueItem $entry.File $item
    Update-StatusLine $item.source.line "skipped"
    Write-Host "Skipped $($item.id)"
}

switch ($Command) {
    "doctor"           { Invoke-Doctor }
    "plan"             { Get-Content -LiteralPath (Resolve-AIOSPath ".aios\prompts\AUTO_FIX.md") -Encoding UTF8 }
    "approved"         { Get-Content -LiteralPath (Resolve-AIOSPath ".aios\prompts\AUTO_FIX_APPROVED.md") -Encoding UTF8 }
    "enqueue-next"     { Invoke-EnqueueNext }
    "queue-status"     { Invoke-QueueStatus }
    "current"          { Invoke-Current }
    "complete-current" { Complete-Current }
    "skip-current"     { Skip-Current }
    "auto-run"         { Start-AutoRun }
    "auto-status"      { Invoke-AutoStatus }
    "auto-resume"      { Resume-AutoRun }
    "auto-stop"        { Stop-AutoRun }
    "finalize-completed-state" { Finalize-CompletedState }
    default {
        Write-Host "AIOS v10.0.2 commands:"
        Write-Host "  doctor"
        Write-Host "  plan"
        Write-Host "  approved"
        Write-Host "  enqueue-next"
        Write-Host "  queue-status"
        Write-Host "  current"
        Write-Host "  complete-current"
        Write-Host "  skip-current"
        Write-Host "  auto-run"
        Write-Host "  auto-status"
        Write-Host "  auto-resume"
        Write-Host "  auto-stop"
        Write-Host "  finalize-completed-state"
    }
}
