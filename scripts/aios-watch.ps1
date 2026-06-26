param(
  [string]$ProjectRoot = "",
  [int]$PollSeconds = 5,
  [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Get-Location).Path
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $ProjectRoot

$StatePath = Join-Path $ProjectRoot ".aios\runtime\watch-state.json"
$WatcherLog = Join-Path $ProjectRoot ".aios\logs\watcher.log"
$QueueDir = Join-Path $ProjectRoot ".aios\queue"
$BugDir = Join-Path $ProjectRoot "docs\bugs"
$AcceptanceDir = Join-Path $ProjectRoot "docs\acceptance"
$InboxDir = Join-Path $ProjectRoot ".aios\inbox"

$WatchFiles = @(
  (Join-Path $ProjectRoot ".aios\logs\console.log"),
  (Join-Path $ProjectRoot ".aios\logs\test.log"),
  (Join-Path $ProjectRoot ".aios\logs\build.log")
)

$ErrorPatterns = @(
  '(?i)Unhandled Runtime Error',
  '(?i)TypeError:',
  '(?i)ReferenceError:',
  '(?i)SyntaxError:',
  '(?i)Module not found',
  '(?i)Build failed',
  '(?i)Failed to compile',
  '(?i)\bFAIL\b',
  '(?i)Test Suites:.*failed',
  '(?i)npm ERR!',
  '(?i)ERR_[A-Z_]+'
)

$IgnorePatterns = @(
  '(?i)warning',
  '(?i)deprecated',
  '(?i)source map'
)

function Ensure-Directory {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-WatcherLog {
  param([Parameter(Mandatory = $true)][string]$Message)
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -LiteralPath $WatcherLog -Value $line -Encoding UTF8
}

function ConvertTo-Hashtable {
  param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    $InputObject
  )

  if ($null -eq $InputObject) { return $null }

  if ($InputObject -is [System.Collections.IDictionary]) {
    $table = @{}
    foreach ($key in $InputObject.Keys) {
      $table[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
    }
    return $table
  }

  if (($InputObject -is [System.Collections.IEnumerable]) -and
      (-not ($InputObject -is [string]))) {
    $items = @()
    foreach ($item in $InputObject) {
      $items += ,(ConvertTo-Hashtable -InputObject $item)
    }
    return $items
  }

  if ($InputObject -is [psobject]) {
    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Length -gt 0) {
      $table = @{}
      foreach ($property in $properties) {
        $table[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
      }
      return $table
    }
  }

  return $InputObject
}

function New-DefaultState {
  return @{
    version = "9.1.4"
    last_positions = @{}
    fingerprints = @{}
    last_bug_id = $null
    updated_at = $null
  }
}

function Load-State {
  if (-not (Test-Path -LiteralPath $StatePath)) {
    return New-DefaultState
  }

  try {
    $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "Empty state" }

    $parsed = $raw | ConvertFrom-Json
    $obj = ConvertTo-Hashtable -InputObject $parsed

    if (-not ($obj -is [hashtable])) { throw "State root is not an object" }
    if (-not $obj.ContainsKey("last_positions")) { $obj["last_positions"] = @{} }
    if (-not $obj.ContainsKey("fingerprints")) { $obj["fingerprints"] = @{} }
    if (-not ($obj["last_positions"] -is [hashtable])) { $obj["last_positions"] = @{} }
    if (-not ($obj["fingerprints"] -is [hashtable])) { $obj["fingerprints"] = @{} }

    return $obj
  } catch {
    Write-WatcherLog -Message "State reset because it could not be read: $($_.Exception.Message)"
    return New-DefaultState
  }
}

function Save-State {
  param([Parameter(Mandatory = $true)][hashtable]$State)

  $State["updated_at"] = (Get-Date).ToString("o")
  $tempPath = "$StatePath.tmp"

  $State |
    ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $tempPath -Encoding UTF8

  Move-Item -LiteralPath $tempPath -Destination $StatePath -Force
}

function Get-Fingerprint {
  param(
    [Parameter(Mandatory = $true)][string]$SourceName,
    [Parameter(Mandatory = $true)][string]$MatchedLine
  )

  $normalized = ($MatchedLine -replace '\d+', '#') -replace '\s+', ' '
  $material = "$SourceName|$($normalized.Trim())"

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($material)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").Substring(0, 16)
  } finally {
    $sha.Dispose()
  }
}

function Test-IsError {
  param([Parameter(Mandatory = $true)][string]$Text)

  foreach ($ignore in $IgnorePatterns) {
    if ($Text -match $ignore) { return $false }
  }

  foreach ($pattern in $ErrorPatterns) {
    if ($Text -match $pattern) { return $true }
  }

  return $false
}

function Get-BranchName {
  try {
    $branch = (& git branch --show-current 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) { return "Unknown" }
    return $branch
  } catch {
    return "Unknown"
  }
}

function New-AutoBug {
  param(
    [Parameter(Mandatory = $true)][string]$SourceFile,
    [Parameter(Mandatory = $true)][string[]]$EvidenceLines,
    [Parameter(Mandatory = $true)][string]$MatchedLine,
    [Parameter(Mandatory = $true)][string]$Fingerprint,
    [Parameter(Mandatory = $true)][hashtable]$State
  )

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $bugId = "BUG-AUTO-$timestamp"
  $branch = Get-BranchName
  $evidence = ($EvidenceLines | Select-Object -Last 80) -join [Environment]::NewLine
  $sourceName = Split-Path -Leaf $SourceFile

  $bugPath = Join-Path $BugDir "$bugId.md"
  $acceptancePath = Join-Path $AcceptanceDir "$bugId.md"
  $queuePath = Join-Path $QueueDir "$bugId.json"
  $promptPath = Join-Path $InboxDir "$bugId-PROMPT.md"

  $bugContent = @"
# ${bugId}: Auto-detected issue

## Status

Detected

## Observed Behavior

AIOS detected an error signal in `$sourceName`.

## Expected Behavior

The related command should complete without the detected error.

## Evidence

- Detected at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Branch: $branch
- Source log: $sourceName
- Fingerprint: $Fingerprint
- Matched line: $MatchedLine

```text
$evidence
```

## Affected Area

Pending Context Builder analysis.

## AIOS Notes

Automatically generated by AIOS v9.1.4 NightWatch Patch 4.
"@

  $acceptanceContent = @"
# Acceptance Criteria: $bugId

## Must Pass

- The detected error no longer appears when the failing command is repeated.
- The root cause is identified with evidence.
- Only approved files are changed.
- Relevant tests or build checks pass.
- Nearby behavior does not regress.
- Verification evidence is recorded.

## Acceptance Mapping

| Criteria | Status | Evidence |
|---|---|---|
| Error removed | Pending | |
| Root cause identified | Pending | |
| Scope controlled | Pending | |
| Tests/build pass | Pending | |
| Regression check complete | Pending | |
"@

  $queueObject = @{
    bug_id = $bugId
    status = "queued"
    detected_at = (Get-Date).ToString("o")
    branch = $branch
    source_log = $sourceName
    fingerprint = $Fingerprint
    matched_line = $MatchedLine
    bug_file = "docs/bugs/$bugId.md"
    acceptance_file = "docs/acceptance/$bugId.md"
    prompt_file = ".aios/inbox/$bugId-PROMPT.md"
  }

  $relativeSource = $SourceFile.Replace($ProjectRoot + "\", "").Replace("\", "/")

  $promptContent = @"
Follow AIOS Enterprise v9.1.2 NightWatch Patch 2.

Process queued bug: $bugId

Read only first:
- .aios/
- docs/bugs/$bugId.md
- docs/acceptance/$bugId.md
- $relativeSource

Rules:
- Do not scan the whole repository.
- Do not read git history.
- Do not modify code during PLAN.
- Do not install or upgrade packages.
- Use the captured log as evidence.
- Stop after PLAN.

Output:
1. Runtime State
2. Bug Summary
3. Evidence
4. Context Summary
5. Allowed Files
6. Root Cause
7. Repair Plan
8. Acceptance Mapping
"@

  Set-Content -LiteralPath $bugPath -Value $bugContent -Encoding UTF8
  Set-Content -LiteralPath $acceptancePath -Value $acceptanceContent -Encoding UTF8
  $queueObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $queuePath -Encoding UTF8
  Set-Content -LiteralPath $promptPath -Value $promptContent -Encoding UTF8

  $State["last_bug_id"] = $bugId
  $State["fingerprints"][$Fingerprint] = (Get-Date).ToString("o")

  Write-WatcherLog -Message "Created $bugId from $sourceName."
}

function Process-LogFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][hashtable]$State
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType File -Path $Path -Force | Out-Null
  }

  $key = $Path.ToLowerInvariant()
  $position = 0

  if ($State["last_positions"].ContainsKey($key)) {
    $position = [int64]$State["last_positions"][$key]
  }

  $fileInfo = Get-Item -LiteralPath $Path
  if ($fileInfo.Length -lt $position) {
    $position = 0
  }

  if ($fileInfo.Length -eq $position) {
    return
  }

  $stream = [System.IO.File]::Open($Path, "Open", "Read", "ReadWrite")
  try {
    [void]$stream.Seek($position, [System.IO.SeekOrigin]::Begin)
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true, 4096, $true)
    try {
      $newText = $reader.ReadToEnd()
    } finally {
      $reader.Dispose()
    }
  } finally {
    $stream.Dispose()
  }

  # Use actual file length after reading, not buffered stream position.
  $State["last_positions"][$key] = (Get-Item -LiteralPath $Path).Length

  if ([string]::IsNullOrWhiteSpace($newText)) { return }

  $lines = $newText -split "`r?`n"
  $window = New-Object System.Collections.Generic.List[string]

  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $window.Add($line)
    if ($window.Count -gt 20) {
      $window.RemoveAt(0)
    }

    if (Test-IsError -Text $line) {
      $sourceName = Split-Path -Leaf $Path
      $fingerprint = Get-Fingerprint -SourceName $sourceName -MatchedLine $line

      if ($State["fingerprints"].ContainsKey($fingerprint)) {
        Write-WatcherLog -Message "Skipped duplicate fingerprint $fingerprint from $sourceName."
        continue
      }

      New-AutoBug `
        -SourceFile $Path `
        -EvidenceLines $window.ToArray() `
        -MatchedLine $line `
        -Fingerprint $fingerprint `
        -State $State

      break
    }
  }
}

Ensure-Directory -Path (Split-Path -Parent $StatePath)
Ensure-Directory -Path (Split-Path -Parent $WatcherLog)
Ensure-Directory -Path $QueueDir
Ensure-Directory -Path $BugDir
Ensure-Directory -Path $AcceptanceDir
Ensure-Directory -Path $InboxDir

# Enforce a single watcher instance per project.
$projectHashBytes = [System.Text.Encoding]::UTF8.GetBytes($ProjectRoot.ToLowerInvariant())
$hashProvider = [System.Security.Cryptography.SHA256]::Create()
try {
  $projectHash = ([BitConverter]::ToString($hashProvider.ComputeHash($projectHashBytes))).Replace("-", "").Substring(0, 16)
} finally {
  $hashProvider.Dispose()
}

$mutexName = "Global\AIOS_NightWatch_$projectHash"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
  Write-WatcherLog -Message "Watcher exit: another instance already owns $mutexName."
  $mutex.Dispose()
  exit 0
}

try {
  Write-WatcherLog -Message "Watcher started for $ProjectRoot."

  do {
    $state = Load-State

    foreach ($file in $WatchFiles) {
      Process-LogFile -Path $file -State $state
    }

    Save-State -State $state

    if (-not $Once) {
      Start-Sleep -Seconds $PollSeconds
    }
  } while (-not $Once)
}
finally {
  try {
    $mutex.ReleaseMutex()
  } catch {}
  $mutex.Dispose()
}
