[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("help", "doctor", "plan", "approved", "enqueue-next", "queue-status", "current", "complete-current", "skip-current")]
    [string]$Command = "help",

    [string]$Root = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = [System.IO.Path]::GetFullPath($Root)

function Resolve-AIOSPath([string]$Relative) {
    return Join-Path -Path $Root -ChildPath $Relative
}

function Get-AIOSTimestamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function ConvertTo-AIOSSlug([string]$Text) {
    $slug = $Text.ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "status-item"
    }
    if ($slug.Length -gt 48) {
        return $slug.Substring(0, 48).Trim("-")
    }
    return $slug
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

function Get-NextStatusItem {
    $statusPath = Resolve-AIOSPath "STATUS.md"
    if (-not (Test-Path -LiteralPath $statusPath)) {
        throw "STATUS.md not found in target project: $statusPath"
    }

    $lines = Get-Content -LiteralPath $statusPath -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*[-*]\s+\[\s\]\s+(.+?)\s*$") {
            return [pscustomobject]@{
                LineNumber = $i + 1
                Text = $Matches[1].Trim()
                Raw = $lines[$i]
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

function Save-QueueItem([string]$Path, $Item) {
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

function Update-StatusLine([int]$LineNumber, [string]$Marker) {
    $statusPath = Resolve-AIOSPath "STATUS.md"
    $lines = @(Get-Content -LiteralPath $statusPath -Encoding UTF8)
    $index = $LineNumber - 1
    if ($index -lt 0 -or $index -ge $lines.Count) {
        throw "STATUS.md line $LineNumber is no longer available."
    }
    $lines[$index] = [regex]::Replace($lines[$index], "^(\s*[-*]\s+)\[[^\]]*\]", "`${1}[$Marker]", 1)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($statusPath, (($lines -join [Environment]::NewLine) + [Environment]::NewLine), $utf8NoBom)
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
        "docs\auto-queue.md"
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
    $next = Get-NextStatusItem
    if ($null -eq $next) {
        Write-Host "No incomplete STATUS.md item found."
        return
    }

    $stamp = Get-AIOSTimestamp
    $slug = ConvertTo-AIOSSlug $next.Text
    $id = "BUG-$stamp-$slug"

    $bugRoot = Ensure-AIOSDirectory ".aios\bugs"
    $acceptanceRoot = Ensure-AIOSDirectory ".aios\acceptance"
    $queueRoot = Ensure-AIOSDirectory ".aios\queue"
    $inboxRoot = Ensure-AIOSDirectory ".aios\inbox"

    $bugPath = Join-Path $bugRoot "$id.md"
    $acceptancePath = Join-Path $acceptanceRoot "$id.md"
    $queuePath = Join-Path $queueRoot "$id.json"
    $inboxPath = Join-Path $inboxRoot "$id.md"

    $createdAt = (Get-Date).ToString("o")
    $bugContent = @"
# $id

Source: STATUS.md line $($next.LineNumber)
Status item: $($next.Text)
Created: $createdAt

## Bug

Implement the next queued STATUS.md item without changing unrelated project behavior.

## Scope

- Read AGENTS.md and AIOS_START.md before implementation.
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
# AIOS Inbox: $id

Queued from STATUS.md line $($next.LineNumber):

> $($next.Text)

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
            line = $next.LineNumber
            text = $next.Text
        }
        files = [ordered]@{
            bug = ".aios/bugs/$id.md"
            acceptance = ".aios/acceptance/$id.md"
            queue = ".aios/queue/$id.json"
            inbox = ".aios/inbox/$id.md"
        }
    }

    Write-NewFile $bugPath $bugContent
    Write-NewFile $acceptancePath $acceptanceContent
    Write-NewFile $inboxPath $inboxContent
    Save-QueueItem $queuePath $queueItem

    Write-Host "Queued $id"
    Write-Host "Bug: $bugPath"
    Write-Host "Acceptance: $acceptancePath"
    Write-Host "Queue: $queuePath"
    Write-Host "Inbox: $inboxPath"
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
    }
}

function Complete-Current {
    $entry = Get-SingleCurrentQueueItem
    $item = $entry.Item
    $item.status = "completed"
    $item | Add-Member -NotePropertyName completedAt -NotePropertyValue (Get-Date).ToString("o") -Force
    Save-QueueItem $entry.File $item
    Update-StatusLine $item.source.line "x"
    Write-Host "Completed $($item.id)"
}

function Skip-Current {
    $entry = Get-SingleCurrentQueueItem
    $item = $entry.Item
    $item.status = "skipped"
    $item | Add-Member -NotePropertyName skippedAt -NotePropertyValue (Get-Date).ToString("o") -Force
    Save-QueueItem $entry.File $item
    Update-StatusLine $item.source.line "-"
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
    }
}
