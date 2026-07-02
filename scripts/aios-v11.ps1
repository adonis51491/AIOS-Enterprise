[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("help", "init", "task-create", "task-status", "plan-record", "approve", "transition", "evidence-record", "render-status", "doctor")]
    [string]$Command = "help",
    [string]$Root = (Get-Location).Path,
    [string]$TaskId,
    [string]$Title,
    [string]$PlanPath,
    [string]$PlanHash,
    [string]$To,
    [string]$CheckName,
    [string]$CheckCommand,
    [int]$ExitCode = 0,
    [string]$CommitSha,
    [string]$Branch,
    [string]$Notes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = [System.IO.Path]::GetFullPath($Root)
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$AllowedStates = @("QUEUED", "PLANNING", "WAITING_APPROVAL", "IMPLEMENTING", "VALIDATING", "PR_READY", "WAITING_MERGE", "COMPLETED", "BLOCKED", "FAILED", "CANCELLED", "SKIPPED")
$TerminalStates = @("COMPLETED", "BLOCKED", "FAILED", "CANCELLED", "SKIPPED")
$Transitions = @{
    QUEUED = @("PLANNING", "BLOCKED", "CANCELLED", "SKIPPED")
    PLANNING = @("WAITING_APPROVAL", "BLOCKED", "FAILED", "CANCELLED")
    WAITING_APPROVAL = @("IMPLEMENTING", "PLANNING", "BLOCKED", "CANCELLED")
    IMPLEMENTING = @("VALIDATING", "BLOCKED", "FAILED", "CANCELLED")
    VALIDATING = @("PR_READY", "IMPLEMENTING", "BLOCKED", "FAILED", "CANCELLED")
    PR_READY = @("WAITING_MERGE", "VALIDATING", "BLOCKED", "CANCELLED")
    WAITING_MERGE = @("COMPLETED", "PR_READY", "BLOCKED", "CANCELLED")
    COMPLETED = @()
    BLOCKED = @("PLANNING", "CANCELLED")
    FAILED = @("PLANNING", "CANCELLED")
    CANCELLED = @()
    SKIPPED = @()
}

function Resolve-PathInRoot([string]$RelativePath) { Join-Path -Path $Root -ChildPath $RelativePath }
function Ensure-Directory([string]$RelativePath) {
    $path = Resolve-PathInRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    return $path
}
function Write-JsonAtomic([string]$Path, $Value) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = Join-Path $parent ((Split-Path -Leaf $Path) + "." + [guid]::NewGuid().ToString("N") + ".tmp")
    try {
        $json = $Value | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($temp, ($json + [Environment]::NewLine), $Utf8NoBom)
        Move-Item -LiteralPath $temp -Destination $Path -Force
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}
function Get-TaskPath([string]$Id) {
    if ([string]::IsNullOrWhiteSpace($Id)) { throw "TaskId is required." }
    if ($Id -notmatch "^[A-Z][A-Z0-9_-]{2,63}$") { throw "Invalid TaskId: $Id" }
    Resolve-PathInRoot ".aios-data\tasks\$Id.json"
}
function Read-Task([string]$Id) {
    $path = Get-TaskPath $Id
    if (-not (Test-Path -LiteralPath $path)) { throw "Task not found: $Id" }
    Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}
function Save-Task($Task) {
    $Task.updatedAt = (Get-Date).ToUniversalTime().ToString("o")
    Write-JsonAtomic -Path (Get-TaskPath $Task.id) -Value $Task
}
function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Add-Event($Task, [string]$Type, [string]$Message) {
    $Task.events = @($Task.events) + [pscustomobject]@{ at = (Get-Date).ToUniversalTime().ToString("o"); type = $Type; message = $Message }
}
function Assert-NoOtherActiveTask([string]$ExceptId) {
    $tasksRoot = Resolve-PathInRoot ".aios-data\tasks"
    if (-not (Test-Path -LiteralPath $tasksRoot)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $tasksRoot -Filter "*.json" -File) {
        $task = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($task.id -ne $ExceptId -and $task.state -notin $TerminalStates) { throw "Another non-terminal task exists: $($task.id) [$($task.state)]" }
    }
}
function New-Task {
    if ([string]::IsNullOrWhiteSpace($Title)) { throw "Title is required." }
    Assert-NoOtherActiveTask -ExceptId $TaskId
    $path = Get-TaskPath $TaskId
    if (Test-Path -LiteralPath $path) { throw "Task already exists: $TaskId" }
    $now = (Get-Date).ToUniversalTime().ToString("o")
    $task = [ordered]@{
        schemaVersion = "11.0.0"; id = $TaskId; title = $Title; state = "QUEUED"
        plan = [ordered]@{ path = $null; sha256 = $null; recordedAt = $null }
        approval = [ordered]@{ approved = $false; planSha256 = $null; approvedAt = $null }
        evidence = @(); dependencies = @(); blockingReason = $null
        createdAt = $now; updatedAt = $now
        events = @([pscustomobject]@{ at = $now; type = "TASK_CREATED"; message = "Task created in Task Store." })
    }
    Write-JsonAtomic -Path $path -Value $task
    Write-Host "Created task $TaskId [QUEUED]"
}
function Record-Plan {
    $task = Read-Task $TaskId
    $fullPlanPath = if ([System.IO.Path]::IsPathRooted($PlanPath)) { $PlanPath } else { Resolve-PathInRoot $PlanPath }
    $hash = Get-Sha256 $fullPlanPath
    $task.plan.path = [System.IO.Path]::GetRelativePath($Root, $fullPlanPath)
    $task.plan.sha256 = $hash
    $task.plan.recordedAt = (Get-Date).ToUniversalTime().ToString("o")
    $task.approval.approved = $false; $task.approval.planSha256 = $null; $task.approval.approvedAt = $null
    if ($task.state -eq "QUEUED") { $task.state = "PLANNING" }
    if ($task.state -eq "PLANNING") { $task.state = "WAITING_APPROVAL" }
    Add-Event $task "PLAN_RECORDED" "Plan recorded with SHA256 $hash."
    Save-Task $task
    Write-Host "Recorded plan for $TaskId"
    Write-Host "Plan SHA256: $hash"
}
function Approve-Plan {
    $task = Read-Task $TaskId
    if ($task.state -ne "WAITING_APPROVAL") { throw "Task must be WAITING_APPROVAL before approval. Current: $($task.state)" }
    if ([string]::IsNullOrWhiteSpace($task.plan.sha256)) { throw "No recorded plan exists for $TaskId." }
    if ($PlanHash.ToLowerInvariant() -ne $task.plan.sha256.ToLowerInvariant()) { throw "Approval hash does not match the recorded plan." }
    $task.approval.approved = $true; $task.approval.planSha256 = $task.plan.sha256; $task.approval.approvedAt = (Get-Date).ToUniversalTime().ToString("o")
    Add-Event $task "PLAN_APPROVED" "Human approval bound to plan SHA256 $($task.plan.sha256)."
    Save-Task $task
    Write-Host "Approved plan for $TaskId"
}
function Move-TaskState {
    $task = Read-Task $TaskId
    $target = $To.ToUpperInvariant()
    if ($target -notin $AllowedStates) { throw "Unknown target state: $target" }
    $current = [string]$task.state
    if ($target -notin @($Transitions[$current])) { throw "Illegal transition: $current -> $target" }
    if ($target -eq "IMPLEMENTING") {
        if (-not $task.approval.approved) { throw "Task has no valid plan approval." }
        if ($task.approval.planSha256 -ne $task.plan.sha256) { throw "Approved plan hash is stale." }
        Assert-NoOtherActiveTask -ExceptId $TaskId
    }
    if ($target -eq "PR_READY") {
        $passing = @($task.evidence | Where-Object { $_.result -eq "PASS" })
        if ($passing.Count -eq 0) { throw "At least one PASS evidence record is required before PR_READY." }
    }
    $task.state = $target
    if ($target -eq "BLOCKED") { $task.blockingReason = $Notes }
    Add-Event $task "STATE_TRANSITION" "$current -> $target"
    Save-Task $task
    Write-Host "${TaskId}: $current -> $target"
}
function Record-Evidence {
    $task = Read-Task $TaskId
    if ([string]::IsNullOrWhiteSpace($CheckName)) { throw "CheckName is required." }
    if ([string]::IsNullOrWhiteSpace($CheckCommand)) { throw "CheckCommand is required." }
    if ([string]::IsNullOrWhiteSpace($CommitSha)) { throw "CommitSha is required." }
    if ([string]::IsNullOrWhiteSpace($Branch)) { throw "Branch is required." }
    $result = if ($ExitCode -eq 0) { "PASS" } else { "FAIL" }
    $record = [pscustomobject]@{ id = [guid]::NewGuid().ToString("N"); check = $CheckName; command = $CheckCommand; exitCode = $ExitCode; result = $result; commitSha = $CommitSha; branch = $Branch; notes = $Notes; recordedAt = (Get-Date).ToUniversalTime().ToString("o") }
    $task.evidence = @($task.evidence) + $record
    Add-Event $task "EVIDENCE_RECORDED" "$CheckName = $result at $CommitSha."
    Save-Task $task
    $bundleRoot = Ensure-Directory ".aios-data\evidence\$TaskId"
    Write-JsonAtomic -Path (Join-Path $bundleRoot ($record.id + ".json")) -Value $record
    Write-Host "Recorded $result evidence for ${TaskId}: $CheckName"
}
function Render-Status {
    $tasksRoot = Ensure-Directory ".aios-data\tasks"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# AIOS Task Status"); $lines.Add(""); $lines.Add("Generated from `.aios-data/tasks/*.json`. Do not edit task states here."); $lines.Add("")
    foreach ($file in Get-ChildItem -LiteralPath $tasksRoot -Filter "*.json" -File | Sort-Object Name) {
        $task = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $lines.Add(('- **{0}** — {1} — `{2}`' -f $task.id, $task.title, $task.state))
    }
    [System.IO.File]::WriteAllText((Resolve-PathInRoot "STATUS.generated.md"), (($lines -join [Environment]::NewLine) + [Environment]::NewLine), $Utf8NoBom)
    Write-Host "Rendered STATUS.generated.md"
}
function Invoke-Doctor {
    $issues = New-Object System.Collections.Generic.List[string]
    $tasksRoot = Ensure-Directory ".aios-data\tasks"
    $seen = @{}; $active = @()
    foreach ($file in Get-ChildItem -LiteralPath $tasksRoot -Filter "*.json" -File) {
        try {
            $task = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($seen.ContainsKey($task.id)) { $issues.Add("Duplicate task ID: $($task.id)") }
            $seen[$task.id] = $true
            if ($task.state -notin $AllowedStates) { $issues.Add("Unknown state for $($task.id): $($task.state)") }
            if ($task.state -notin $TerminalStates) { $active += $task.id }
            if ($task.approval.approved -and $task.approval.planSha256 -ne $task.plan.sha256) { $issues.Add("Stale approval hash for $($task.id)") }
            foreach ($evidence in @($task.evidence)) {
                if ([string]::IsNullOrWhiteSpace($evidence.commitSha) -or [string]::IsNullOrWhiteSpace($evidence.command)) { $issues.Add("Incomplete evidence for $($task.id)") }
            }
        }
        catch { $issues.Add("Unreadable task file $($file.Name): $($_.Exception.Message)") }
    }
    if ($active.Count -gt 1) { $issues.Add("More than one non-terminal task exists: $($active -join ', ')") }
    foreach ($pattern in @(".aios\.aios", "scripts\scripts", "templates\templates", "docs\docs")) {
        $match = Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match [regex]::Escape($pattern) } | Select-Object -First 1
        if ($null -ne $match) { $issues.Add("Nested duplicate directory detected: $($match.FullName)") }
    }
    if ($issues.Count -gt 0) {
        foreach ($issueText in $issues) { Write-Host "[FAIL] $issueText" }
        throw "AIOS v11 doctor found $($issues.Count) issue(s)."
    }
    Write-Host "AIOS v11 doctor: HEALTHY"
}

switch ($Command) {
    "help" { Write-Host "AIOS Enterprise v11 — Governed Engineering Orchestrator" }
    "init" { Ensure-Directory ".aios-data\tasks" | Out-Null; Ensure-Directory ".aios-data\plans" | Out-Null; Ensure-Directory ".aios-data\evidence" | Out-Null; Write-Host "Initialized AIOS v11 project data store." }
    "task-create" { New-Task }
    "task-status" { Read-Task $TaskId | ConvertTo-Json -Depth 20 }
    "plan-record" { Record-Plan }
    "approve" { Approve-Plan }
    "transition" { Move-TaskState }
    "evidence-record" { Record-Evidence }
    "render-status" { Render-Status }
    "doctor" { Invoke-Doctor }
}
