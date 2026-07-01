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
$ZhColon = [string][char]0xFF1A
$ZhBuild = -join ([char[]]@(0x5EFA,0x7F6E))
$ZhDeploy = -join ([char[]]@(0x90E8,0x7F72))
$ZhStable = -join ([char[]]@(0x7A69,0x5B9A,0x6027))
$ZhHome = -join ([char[]]@(0x9996,0x9801))
$ZhStory = -join ([char[]]@(0x6545,0x4E8B))
$ZhTask = -join ([char[]]@(0x4E2D,0x6587,0x4EFB,0x52D9))
$ZhNoId = -join ([char[]]@(0x6C92,0x6709,0x6B63,0x5F0F,0x0049,0x0044))
$ZhDuplicateAppointment = -join ([char[]]@(0x9632,0x6B62,0x540C,0x6642,0x6BB5,0x91CD,0x8907,0x9810,0x7D04))
$CreatedProjects = New-Object System.Collections.Generic.List[string]

function New-TestProject([string]$Name, [string[]]$StatusLines) {
    $path = Join-Path $env:TEMP ("aios-auto-queue-$Name-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $CreatedProjects.Add($path) | Out-Null
    [System.IO.File]::WriteAllLines((Join-Path $path "STATUS.md"), $StatusLines, $Utf8NoBom)
    return $path
}

function Remove-TestProject([string]$ProjectRoot) {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { return }
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $fullPath = [System.IO.Path]::GetFullPath($ProjectRoot)
    $leaf = Split-Path -Leaf $fullPath
    if (-not $fullPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean fixture outside temp: $fullPath"
    }
    if ($fullPath.TrimEnd('\') -eq $tempRoot.TrimEnd('\')) {
        throw "Refusing to clean temp root: $fullPath"
    }
    if ($fullPath.TrimEnd('\') -eq ([System.IO.Path]::GetFullPath($AIOSRoot)).TrimEnd('\')) {
        throw "Refusing to clean repository root: $fullPath"
    }
    if ($leaf -notmatch '^aios-auto-queue-[A-Za-z0-9_-]+-[0-9a-f]{32}$') {
        throw "Refusing to clean unexpected fixture name: $leaf"
    }
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

function Invoke-AIOS([string]$ProjectRoot, [string]$Command) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath $Command -Root $ProjectRoot *>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = ($output | Out-String)
    }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-FileExists([string]$Path) {
    Assert-True (Test-Path -LiteralPath $Path) "Expected file to exist: $Path"
}

function Assert-FileMissing([string]$Path) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Expected file to be absent: $Path"
}

function Read-JsonFile([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$tests = @()

$tests += [pscustomobject]@{
    Name = "Chinese title preserves CONTEST-001 and output contract"
    Run = {
        $project = New-TestProject "contest001" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "1. CONTEST-001$ZhColon$ZhBuild, $ZhDeploy, core page $ZhStable",
            "2. CONTEST-002$ZhColon$ZhHome $ZhStory and CTA"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "Queued CONTEST-001") $result.Output
        Assert-FileExists (Join-Path $project "docs\bugs\CONTEST-001.md")
        Assert-FileExists (Join-Path $project "docs\acceptance\CONTEST-001.md")
        Assert-FileExists (Join-Path $project ".aios\queue\CONTEST-001.json")
        Assert-FileExists (Join-Path $project ".aios\inbox\CONTEST-001-PROMPT.md")
        Assert-FileMissing (Join-Path $project ".aios\bugs\CONTEST-001.md")
        Assert-FileMissing (Join-Path $project ".aios\acceptance\CONTEST-001.md")
        Assert-FileMissing (Join-Path $project ".aios\inbox\CONTEST-001.md")
        $queue = Read-JsonFile (Join-Path $project ".aios\queue\CONTEST-001.json")
        Assert-True ($queue.id -eq "CONTEST-001") "Expected queue id CONTEST-001, got $($queue.id)"
        Assert-True ($queue.files.bug -eq "docs/bugs/CONTEST-001.md") "Wrong bug path"
        Assert-True ($queue.files.acceptance -eq "docs/acceptance/CONTEST-001.md") "Wrong acceptance path"
        Assert-True ($queue.files.inbox -eq ".aios/inbox/CONTEST-001-PROMPT.md") "Wrong inbox path"
    }
}

$tests += [pscustomobject]@{
    Name = "First completed item selects next eligible formal ID"
    Run = {
        $project = New-TestProject "next" @(
            "# STATUS",
            "",
            "## 工作順序",
            "",
            "1. CONTEST-001$ZhColon completed item DONE",
            "2. CONTEST-002$ZhColon$ZhHome $ZhStory and CTA"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "Queued CONTEST-002") $result.Output
        Assert-FileExists (Join-Path $project ".aios\queue\CONTEST-002.json")
    }
}

$tests += [pscustomobject]@{
    Name = "Ordinary text and informal checklist never enqueue"
    Run = {
        $project = New-TestProject "ordinary" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "- [ ] Fix the homepage copy",
            "- $ZhTask ordinary note",
            "1. $ZhNoId"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "NO_ELIGIBLE_STATUS_ITEM") $result.Output
        Assert-FileMissing (Join-Path $project ".aios")
        Assert-FileMissing (Join-Path $project "docs")
    }
}

$tests += [pscustomobject]@{
    Name = "Priority work order section beats earlier non-priority formal ID"
    Run = {
        $workOrderHeading = -join ([char[]]@(0x5DE5,0x4F5C,0x9806,0x5E8F))
        $project = New-TestProject "priority" @(
            "# STATUS",
            "",
            "## Backlog",
            "",
            "1. CONTEST-999: older backlog item",
            "",
            "## $workOrderHeading",
            "",
            "1. CONTEST-004: priority work order item"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "Queued CONTEST-004") $result.Output
        Assert-FileExists (Join-Path $project ".aios\queue\CONTEST-004.json")
        Assert-FileMissing (Join-Path $project ".aios\queue\CONTEST-999.json")
    }
}
$tests += [pscustomobject]@{
    Name = "Duplicate enqueue is blocked"
    Run = {
        $project = New-TestProject "duplicate" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "1. BUG-101$ZhColon data sync fix",
            "2. BUG-102$ZhColon reminder fix"
        )
        $first = Invoke-AIOS $project "enqueue-next"
        Assert-True ($first.ExitCode -eq 0) $first.Output
        $second = Invoke-AIOS $project "enqueue-next"
        Assert-True ($second.ExitCode -ne 0) "Duplicate enqueue unexpectedly succeeded"
        Assert-True ($second.Output -match "already exists") $second.Output
    }
}

$tests += [pscustomobject]@{
    Name = "Selected task existing target refuses overwrite and leaves no partial artifacts"
    Run = {
        $project = New-TestProject "existing-docs" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "1. CONTEST-003$ZhColon preserve existing docs"
        )
        New-Item -ItemType Directory -Path (Join-Path $project "docs\bugs") -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $project "docs\bugs\CONTEST-003.md"), "BUG SENTINEL", $Utf8NoBom)
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -ne 0) "Existing selected target unexpectedly succeeded"
        Assert-True ($result.Output -match "Refusing to overwrite existing file") $result.Output
        Assert-True ((Get-Content -LiteralPath (Join-Path $project "docs\bugs\CONTEST-003.md") -Raw) -eq "BUG SENTINEL") "Bug doc was overwritten"
        Assert-FileMissing (Join-Path $project "docs\acceptance\CONTEST-003.md")
        Assert-FileMissing (Join-Path $project ".aios\queue\CONTEST-003.json")
        Assert-FileMissing (Join-Path $project ".aios\inbox\CONTEST-003-PROMPT.md")
    }
}

$tests += [pscustomobject]@{
    Name = "Blocked task artifacts exist and next eligible BUG-001 enqueues"
    Run = {
        $project = New-TestProject "blocked-artifacts" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "* [x] CONTEST-001$ZhColon completed",
            "* [x] CONTEST-002$ZhColon completed",
            "* [x] CONTEST-003$ZhColon completed",
            "* [x] CONTEST-004$ZhColon completed",
            "* [-] CONTEST-005$ZhColon AI blocked",
            "* [-] CONTEST-006$ZhColon dependency_blocked: depends on CONTEST-005",
            "* [x] BUG-002$ZhColon completed",
            "* [ ] BUG-001$ZhColon $ZhDuplicateAppointment"
        )
        New-Item -ItemType Directory -Path (Join-Path $project ".aios\queue") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project ".aios\inbox") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project "docs\bugs") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project "docs\acceptance") -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\queue\CONTEST-005.json"), "{`"id`":`"CONTEST-005`",`"status`":`"blocked`"}", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\inbox\CONTEST-005-PROMPT.md"), "PROMPT SENTINEL", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project "docs\bugs\CONTEST-005.md"), "BUG SENTINEL", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project "docs\acceptance\CONTEST-005.md"), "ACCEPTANCE SENTINEL", $Utf8NoBom)
        $hashesBefore = @{
            Queue = Get-FileSha256 (Join-Path $project ".aios\queue\CONTEST-005.json")
            Inbox = Get-FileSha256 (Join-Path $project ".aios\inbox\CONTEST-005-PROMPT.md")
            Bug = Get-FileSha256 (Join-Path $project "docs\bugs\CONTEST-005.md")
            Acceptance = Get-FileSha256 (Join-Path $project "docs\acceptance\CONTEST-005.md")
        }

        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "Queued BUG-001") $result.Output

        $queue = Read-JsonFile (Join-Path $project ".aios\queue\BUG-001.json")
        Assert-True ($queue.id -eq "BUG-001") "Expected queue id BUG-001, got $($queue.id)"
        Assert-True ($queue.files.bug -eq "docs/bugs/BUG-001.md") "Wrong selected bug path"
        Assert-True ($queue.files.acceptance -eq "docs/acceptance/BUG-001.md") "Wrong selected acceptance path"
        Assert-True ($queue.files.queue -eq ".aios/queue/BUG-001.json") "Wrong selected queue path"
        Assert-True ($queue.files.inbox -eq ".aios/inbox/BUG-001-PROMPT.md") "Wrong selected inbox path"
        Assert-True ((Get-Content -LiteralPath (Join-Path $project "docs\bugs\BUG-001.md") -Raw) -match "# BUG-001") "Bug doc did not use BUG-001"
        Assert-True ((Get-Content -LiteralPath (Join-Path $project "docs\acceptance\BUG-001.md") -Raw) -match "# Acceptance: BUG-001") "Acceptance doc did not use BUG-001"
        Assert-True ((Get-Content -LiteralPath (Join-Path $project ".aios\inbox\BUG-001-PROMPT.md") -Raw) -match "BUG-001") "Inbox did not use BUG-001"

        Assert-True ((Get-FileSha256 (Join-Path $project ".aios\queue\CONTEST-005.json")) -eq $hashesBefore.Queue) "CONTEST-005 queue was modified"
        Assert-True ((Get-FileSha256 (Join-Path $project ".aios\inbox\CONTEST-005-PROMPT.md")) -eq $hashesBefore.Inbox) "CONTEST-005 inbox was modified"
        Assert-True ((Get-FileSha256 (Join-Path $project "docs\bugs\CONTEST-005.md")) -eq $hashesBefore.Bug) "CONTEST-005 bug doc was modified"
        Assert-True ((Get-FileSha256 (Join-Path $project "docs\acceptance\CONTEST-005.md")) -eq $hashesBefore.Acceptance) "CONTEST-005 acceptance doc was modified"
    }
}

$tests += [pscustomobject]@{
    Name = "Completed blocked and dependency-blocked tasks are skipped"
    Run = {
        $project = New-TestProject "skip-ineligible" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "* [x] CONTEST-001$ZhColon completed",
            "* [-] CONTEST-002$ZhColon blocked",
            "* [ ] CONTEST-003$ZhColon dependency_blocked: depends on CONTEST-002",
            "* [ ] BUG-001$ZhColon first eligible"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "Queued BUG-001") $result.Output
        Assert-FileMissing (Join-Path $project ".aios\queue\CONTEST-001.json")
        Assert-FileMissing (Join-Path $project ".aios\queue\CONTEST-002.json")
        Assert-FileMissing (Join-Path $project ".aios\queue\CONTEST-003.json")
    }
}

$tests += [pscustomobject]@{
    Name = "Partial artifact write failure removes selected task artifacts"
    Run = {
        $project = New-TestProject "partial-failure" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "* [ ] BUG-001$ZhColon partial failure cleanup"
        )
        $oldValue = $env:AIOS_TEST_FAIL_AFTER_ARTIFACT_COUNT
        try {
            $env:AIOS_TEST_FAIL_AFTER_ARTIFACT_COUNT = "2"
            $result = Invoke-AIOS $project "enqueue-next"
        }
        finally {
            if ($null -eq $oldValue) {
                Remove-Item Env:\AIOS_TEST_FAIL_AFTER_ARTIFACT_COUNT -ErrorAction SilentlyContinue
            }
            else {
                $env:AIOS_TEST_FAIL_AFTER_ARTIFACT_COUNT = $oldValue
            }
        }
        Assert-True ($result.ExitCode -ne 0) "Simulated failure unexpectedly succeeded"
        Assert-True ($result.Output -match "AIOS_TEST_SIMULATED_ARTIFACT_FAILURE") $result.Output
        Assert-FileMissing (Join-Path $project "docs\bugs\BUG-001.md")
        Assert-FileMissing (Join-Path $project "docs\acceptance\BUG-001.md")
        Assert-FileMissing (Join-Path $project ".aios\inbox\BUG-001-PROMPT.md")
        Assert-FileMissing (Join-Path $project ".aios\queue\BUG-001.json")
    }
}

$tests += [pscustomobject]@{
    Name = "Queued or active task blocks creating another task"
    Run = {
        $project = New-TestProject "active-blocks" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "* [ ] BUG-001$ZhColon should not enqueue"
        )
        New-Item -ItemType Directory -Path (Join-Path $project ".aios\queue") -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $project ".aios\queue\CONTEST-099.json"), "{`"id`":`"CONTEST-099`",`"status`":`"active`"}", $Utf8NoBom)
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -ne 0) "enqueue-next unexpectedly allowed a second current task"
        Assert-True ($result.Output -match "already exists: CONTEST-099 \[active\]") $result.Output
        Assert-FileMissing (Join-Path $project ".aios\queue\BUG-001.json")
    }
}

$tests += [pscustomobject]@{
    Name = "Chinese BUG-001 title preserves formal selected ID"
    Run = {
        $project = New-TestProject "bug001-zh" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "* [-] CONTEST-005$ZhColon blocked",
            "* [ ] BUG-001$ZhColon $ZhDuplicateAppointment"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "Queued BUG-001") $result.Output
        $queue = Read-JsonFile (Join-Path $project ".aios\queue\BUG-001.json")
        Assert-True ($queue.id -eq "BUG-001") "Chinese title did not preserve BUG-001 id"
        Assert-True ($queue.source.text -match [regex]::Escape($ZhDuplicateAppointment)) "Chinese title was not preserved"
    }
}

$tests += [pscustomobject]@{
    Name = "Queue status current complete and skip work on ordered formal IDs"
    Run = {
        $project = New-TestProject "lifecycle" @(
            "# STATUS",
            "",
            "## 明確排序清單",
            "",
            "1. CONTEST-010$ZhColon first item",
            "2. CONTEST-011$ZhColon second item"
        )
        Assert-True ((Invoke-AIOS $project "enqueue-next").ExitCode -eq 0) "First enqueue failed"
        $status = Invoke-AIOS $project "queue-status"
        Assert-True ($status.Output -match "CONTEST-010 \[queued\]") $status.Output
        $current = Invoke-AIOS $project "current"
        Assert-True ($current.Output -match "Inbox: .aios/inbox/CONTEST-010-PROMPT.md") $current.Output
        Assert-True ((Invoke-AIOS $project "complete-current").ExitCode -eq 0) "complete-current failed"
        $statusText = Get-Content -LiteralPath (Join-Path $project "STATUS.md") -Raw -Encoding UTF8
        Assert-True ($statusText -match "CONTEST-010.+DONE") "complete-current did not mark ordered item DONE"
        Assert-True ((Invoke-AIOS $project "enqueue-next").ExitCode -eq 0) "Second enqueue failed"
        Assert-True ((Invoke-AIOS $project "skip-current").ExitCode -eq 0) "skip-current failed"
        $statusText = Get-Content -LiteralPath (Join-Path $project "STATUS.md") -Raw -Encoding UTF8
        Assert-True ($statusText -match "CONTEST-011.+SKIPPED") "skip-current did not mark ordered item SKIPPED"
    }
}

$tests += [pscustomobject]@{
    Name = "No formal ID creates no files"
    Run = {
        $project = New-TestProject "none" @(
            "# STATUS",
            "",
            "## 工作順序",
            "",
            "1. $ZhTask but no formal ID",
            "2. Another task without an ID",
            "- [ ] Checklist without an ID"
        )
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ($result.Output -match "NO_ELIGIBLE_STATUS_ITEM") $result.Output
        Assert-FileMissing (Join-Path $project ".aios")
        Assert-FileMissing (Join-Path $project "docs")
    }
}


$tests += [pscustomobject]@{
    Name = "Auto queue fixture cleanup removes owned temp project"
    Run = {
        $project = New-TestProject "cleanup-owned" @("# STATUS", "", "1. BUG-001$ZhColon cleanup")
        Assert-True (Test-Path -LiteralPath $project) "Fixture was not created"
        Remove-TestProject $project
        Assert-True (-not (Test-Path -LiteralPath $project)) "Owned fixture was not cleaned"
    }
}

$tests += [pscustomobject]@{
    Name = "Auto queue fixture cleanup preserves unrelated same-prefix fixture"
    Run = {
        $unrelated = Join-Path $env:TEMP ("aios-auto-queue-unrelated-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $unrelated -Force | Out-Null
        try {
            [System.IO.File]::WriteAllText((Join-Path $unrelated "sentinel.txt"), "keep", $Utf8NoBom)
            $project = New-TestProject "cleanup-preserve" @("# STATUS", "", "1. BUG-001$ZhColon cleanup")
            Remove-TestProject $project
            Assert-True (Test-Path -LiteralPath $unrelated) "Unrelated same-prefix fixture was deleted"
            Assert-True ((Get-Content -LiteralPath (Join-Path $unrelated "sentinel.txt") -Raw) -eq "keep") "Unrelated sentinel changed"
        }
        finally {
            if (Test-Path -LiteralPath $unrelated) {
                Remove-Item -LiteralPath $unrelated -Recurse -Force
            }
        }
    }
}

$tests += [pscustomobject]@{
    Name = "Auto queue fixture cleanup helper runs after assertion failure simulation"
    Run = {
        $project = New-TestProject "cleanup-failure" @("# STATUS", "", "1. BUG-001$ZhColon cleanup")
        try {
            throw "SIMULATED_ASSERTION_FAILURE"
        }
        catch {
            Assert-True ($_.Exception.Message -eq "SIMULATED_ASSERTION_FAILURE") "Unexpected simulated error"
        }
        finally {
            Remove-TestProject $project
        }
        Assert-True (-not (Test-Path -LiteralPath $project)) "Fixture survived simulated assertion failure"
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

Write-Host "All auto queue runtime tests passed."
