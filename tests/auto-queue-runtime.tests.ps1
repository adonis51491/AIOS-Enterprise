[CmdletBinding()]
param(
    [string]$AIOSRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

function New-TestProject([string]$Name, [string[]]$StatusLines) {
    $path = Join-Path $env:TEMP ("aios-auto-queue-$Name-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    [System.IO.File]::WriteAllLines((Join-Path $path "STATUS.md"), $StatusLines, $Utf8NoBom)
    return $path
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
    Name = "Existing bug and acceptance docs are not overwritten"
    Run = {
        $project = New-TestProject "existing-docs" @(
            "# STATUS",
            "",
            "## Current Sprint",
            "",
            "1. CONTEST-003$ZhColon preserve existing docs"
        )
        New-Item -ItemType Directory -Path (Join-Path $project "docs\bugs") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project "docs\acceptance") -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $project "docs\bugs\CONTEST-003.md"), "BUG SENTINEL", $Utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $project "docs\acceptance\CONTEST-003.md"), "ACCEPTANCE SENTINEL", $Utf8NoBom)
        $result = Invoke-AIOS $project "enqueue-next"
        Assert-True ($result.ExitCode -eq 0) $result.Output
        Assert-True ((Get-Content -LiteralPath (Join-Path $project "docs\bugs\CONTEST-003.md") -Raw) -eq "BUG SENTINEL") "Bug doc was overwritten"
        Assert-True ((Get-Content -LiteralPath (Join-Path $project "docs\acceptance\CONTEST-003.md") -Raw) -eq "ACCEPTANCE SENTINEL") "Acceptance doc was overwritten"
        $queue = Read-JsonFile (Join-Path $project ".aios\queue\CONTEST-003.json")
        Assert-True ($queue.files.bug -eq "docs/bugs/CONTEST-003.md") "Queue did not reference existing bug doc"
        Assert-True ($queue.files.acceptance -eq "docs/acceptance/CONTEST-003.md") "Queue did not reference existing acceptance doc"
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

foreach ($test in $tests) {
    Write-Host "[TEST] $($test.Name)"
    & $test.Run
    Write-Host "[PASS] $($test.Name)"
}

Write-Host "All auto queue runtime tests passed."
