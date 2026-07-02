[CmdletBinding()]
param(
    [string]$AIOSRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Runtime = Join-Path $AIOSRoot "scripts\aios-v11.ps1"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Projects = New-Object System.Collections.Generic.List[string]

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-TestProject([string]$Name) {
    $path = Join-Path $env:TEMP ("aios-v11-$Name-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $Projects.Add($path) | Out-Null
    return $path
}

function Remove-TestProject([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($temp, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing cleanup outside temp: $full"
    }
    if ((Split-Path -Leaf $full) -notmatch '^aios-v11-[A-Za-z0-9_-]+-[0-9a-f]{32}$') {
        throw "Unexpected fixture name: $full"
    }
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}

function Invoke-Runtime([string]$Project, [string[]]$Arguments, [bool]$ExpectFailure = $false) {
    $output = & pwsh -NoProfile -File $Runtime @Arguments -Root $Project 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($ExpectFailure) {
        Assert-True ($code -ne 0) "Expected command failure but exit code was zero. Output: $output"
    }
    else {
        Assert-True ($code -eq 0) "Command failed with exit code $code. Output: $output"
    }
    return $output
}

try {
    $project = New-TestProject "happy-path"
    Invoke-Runtime $project @("init") | Out-Null
    Invoke-Runtime $project @("task-create", "-TaskId", "BUG-001", "-Title", "Test task") | Out-Null

    $taskPath = Join-Path $project ".aios-data\tasks\BUG-001.json"
    Assert-True (Test-Path -LiteralPath $taskPath) "Task file was not created."
    $task = Get-Content -LiteralPath $taskPath -Raw | ConvertFrom-Json
    Assert-True ($task.state -eq "QUEUED") "New task did not start in QUEUED."

    Invoke-Runtime $project @("transition", "-TaskId", "BUG-001", "-To", "PLANNING") | Out-Null
    $planPath = Join-Path $project "BUG-001-PLAN.md"
    [System.IO.File]::WriteAllText($planPath, "# Plan`n`nModify one file.`n", $Utf8NoBom)
    $planOutput = Invoke-Runtime $project @("plan-record", "-TaskId", "BUG-001", "-PlanPath", $planPath)
    $hash = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True ($planOutput -match $hash) "Plan hash was not reported."

    Invoke-Runtime $project @("approve", "-TaskId", "BUG-001", "-PlanHash", ("0" * 64)) $true | Out-Null
    Invoke-Runtime $project @("approve", "-TaskId", "BUG-001", "-PlanHash", $hash) | Out-Null
    Invoke-Runtime $project @("transition", "-TaskId", "BUG-001", "-To", "IMPLEMENTING") | Out-Null
    Invoke-Runtime $project @("transition", "-TaskId", "BUG-001", "-To", "VALIDATING") | Out-Null

    Invoke-Runtime $project @(
        "evidence-record",
        "-TaskId", "BUG-001",
        "-CheckName", "build",
        "-CheckCommand", "npm.cmd run build",
        "-ExitCode", "0",
        "-CommitSha", "0123456789abcdef",
        "-Branch", "fix/BUG-001"
    ) | Out-Null

    Invoke-Runtime $project @("transition", "-TaskId", "BUG-001", "-To", "PR_READY") | Out-Null
    Invoke-Runtime $project @("transition", "-TaskId", "BUG-001", "-To", "WAITING_MERGE") | Out-Null
    Invoke-Runtime $project @("transition", "-TaskId", "BUG-001", "-To", "COMPLETED") | Out-Null
    Invoke-Runtime $project @("doctor") | Out-Null
    Invoke-Runtime $project @("render-status") | Out-Null

    $final = Get-Content -LiteralPath $taskPath -Raw | ConvertFrom-Json
    Assert-True ($final.state -eq "COMPLETED") "Task did not reach COMPLETED."
    Assert-True (@($final.evidence).Count -eq 1) "Evidence was not recorded."
    Assert-True (Test-Path -LiteralPath (Join-Path $project "STATUS.generated.md")) "Generated status is missing."

    $singleActive = New-TestProject "single-active"
    Invoke-Runtime $singleActive @("init") | Out-Null
    Invoke-Runtime $singleActive @("task-create", "-TaskId", "BUG-101", "-Title", "First") | Out-Null
    Invoke-Runtime $singleActive @("task-create", "-TaskId", "BUG-102", "-Title", "Second") $true | Out-Null

    $illegal = New-TestProject "illegal-transition"
    Invoke-Runtime $illegal @("init") | Out-Null
    Invoke-Runtime $illegal @("task-create", "-TaskId", "BUG-201", "-Title", "Illegal") | Out-Null
    Invoke-Runtime $illegal @("transition", "-TaskId", "BUG-201", "-To", "COMPLETED") $true | Out-Null

    $noEvidence = New-TestProject "evidence-gate"
    Invoke-Runtime $noEvidence @("init") | Out-Null
    Invoke-Runtime $noEvidence @("task-create", "-TaskId", "BUG-301", "-Title", "Evidence gate") | Out-Null
    Invoke-Runtime $noEvidence @("transition", "-TaskId", "BUG-301", "-To", "PLANNING") | Out-Null
    $noEvidencePlan = Join-Path $noEvidence "plan.md"
    [System.IO.File]::WriteAllText($noEvidencePlan, "plan", $Utf8NoBom)
    Invoke-Runtime $noEvidence @("plan-record", "-TaskId", "BUG-301", "-PlanPath", $noEvidencePlan) | Out-Null
    $noEvidenceHash = (Get-FileHash $noEvidencePlan -Algorithm SHA256).Hash.ToLowerInvariant()
    Invoke-Runtime $noEvidence @("approve", "-TaskId", "BUG-301", "-PlanHash", $noEvidenceHash) | Out-Null
    Invoke-Runtime $noEvidence @("transition", "-TaskId", "BUG-301", "-To", "IMPLEMENTING") | Out-Null
    Invoke-Runtime $noEvidence @("transition", "-TaskId", "BUG-301", "-To", "VALIDATING") | Out-Null
    Invoke-Runtime $noEvidence @("transition", "-TaskId", "BUG-301", "-To", "PR_READY") $true | Out-Null

    Write-Host "All AIOS v11 runtime tests passed."
}
finally {
    foreach ($project in @($Projects)) {
        Remove-TestProject $project
    }
}
