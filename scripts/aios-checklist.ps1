param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$statusPath = Join-Path $ProjectRoot "STATUS.md"
$bugsPath = Join-Path $ProjectRoot "BUGS.md"
$acceptancePath = Join-Path $ProjectRoot "ACCEPTANCE.md"
$reportDir = Join-Path $ProjectRoot ".aios\reports"
$reportPath = Join-Path $reportDir "TODAY_CHECKLIST.md"

foreach ($path in @($statusPath, $bugsPath, $acceptancePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
}

New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

# Read source files explicitly as UTF-8.
$statusText = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8
$bugsText = Get-Content -LiteralPath $bugsPath -Raw -Encoding UTF8
$acceptanceText = Get-Content -LiteralPath $acceptancePath -Raw -Encoding UTF8

function Get-BugSection {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$BugId
    )

    $escaped = [regex]::Escape($BugId)
    $pattern = "(?ms)^##\s+$escaped\b.*?(?=^##\s+BUG-\d{3}\b|\z)"
    $match = [regex]::Match($Text, $pattern)

    if ($match.Success) {
        return $match.Value.Trim()
    }

    return $null
}

# Select the first bug mentioned in STATUS.md that is still OPEN in BUGS.md.
$selectedBugId = $null
$statusBugIds = [regex]::Matches(
    $statusText,
    '\bBUG-\d{3}\b',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
) | ForEach-Object {
    $_.Value.ToUpperInvariant()
} | Select-Object -Unique

foreach ($candidate in $statusBugIds) {
    $candidateSection = Get-BugSection -Text $bugsText -BugId $candidate

    if (
        $candidateSection -and
        $candidateSection -match '(?im)^\s*-\s*狀態\s*[：:]\s*OPEN\s*$'
    ) {
        $selectedBugId = $candidate
        break
    }
}

# Fallback: choose the first OPEN bug in BUGS.md.
if (-not $selectedBugId) {
    $allBugSections = [regex]::Matches(
        $bugsText,
        '(?ms)^##\s+(BUG-\d{3})\b.*?(?=^##\s+BUG-\d{3}\b|\z)'
    )

    foreach ($section in $allBugSections) {
        if ($section.Value -match '(?im)^\s*-\s*狀態\s*[：:]\s*OPEN\s*$') {
            $selectedBugId = $section.Groups[1].Value.ToUpperInvariant()
            break
        }
    }
}

if (-not $selectedBugId) {
    throw "No OPEN Bug ID was found in STATUS.md or BUGS.md."
}

$bugSection = Get-BugSection -Text $bugsText -BugId $selectedBugId

if (-not $bugSection) {
    throw "Bug section not found in BUGS.md: $selectedBugId"
}

$escapedBugId = [regex]::Escape($selectedBugId)

function Get-FieldValue {
    param(
        [Parameter(Mandatory = $true)][string]$Section,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $escapedLabel = [regex]::Escape($Label)
    $match = [regex]::Match(
        $Section,
        "(?im)^\s*-\s*$escapedLabel\s*[：:]\s*(.+)$"
    )

    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return "MISSING"
}

$titleMatch = [regex]::Match(
    $bugSection,
    "(?m)^##\s+$escapedBugId\s*[：:]?\s*(.+)$"
)

$bugTitle = if ($titleMatch.Success) {
    $titleMatch.Groups[1].Value.Trim()
} else {
    "MISSING"
}

$priority = Get-FieldValue -Section $bugSection -Label "優先級"
$bugStatus = Get-FieldValue -Section $bugSection -Label "狀態"
$module = Get-FieldValue -Section $bugSection -Label "模組"
$impact = Get-FieldValue -Section $bugSection -Label "影響"

# Try to locate a bug-specific acceptance section.
$acceptancePattern = "(?ms)^##[^\r\n]*\b$escapedBugId\b[^\r\n]*\r?\n.*?(?=^##\s+|\z)"
$acceptanceMatch = [regex]::Match($acceptanceText, $acceptancePattern)

if ($acceptanceMatch.Success) {
    $acceptanceSection = $acceptanceMatch.Value.Trim()
} else {
    $acceptanceSection = @'
- [ ] MISSING：ACCEPTANCE.md 找不到此 Bug 的專屬驗收段落
  - 狀態：MISSING
  - 驗證方式：補齊 ACCEPTANCE.md
  - 證據：
'@
}

$normalizedAcceptance = $acceptanceSection `
    -replace '(?m)^\s*\*\s*\\?\[[xX ]\]\s*', '- [ ] ' `
    -replace '(?m)^\s*-\s*\\?\[[xX ]\]\s*', '- [ ] '

$missingItems = New-Object System.Collections.Generic.List[string]

if ($priority -eq "MISSING") {
    $missingItems.Add("Priority")
}
if ($module -eq "MISSING") {
    $missingItems.Add("Module")
}
if (-not $acceptanceMatch.Success) {
    $missingItems.Add("Acceptance Criteria")
}

if ($missingItems.Count -eq 0) {
    $readyForPlan = "YES"
    $missingText = "- 無"
    $blockingText = "- 無，可進入 PLAN"
    $nextAction = "針對 $selectedBugId 產生 Root Cause、Relevant Files、Repair Plan 與 Validation Plan，完成後等待批准 IMPLEMENT。"
} else {
    $readyForPlan = "NO"
    $missingLines = foreach ($item in $missingItems) {
        "- $item"
    }
    $missingText = $missingLines -join [Environment]::NewLine
    $blockingText = "- 文件資訊不足，補齊後才能進入 PLAN"
    $nextAction = "先補齊 Missing Information。"
}

$today = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$reportLines = @(
    "# 今日 Bug 修復清單",
    "",
    "產生時間：$today",
    "",
    "## 今日任務",
    "",
    "- Selected Bug ID：$selectedBugId",
    "- Priority：$priority",
    "- Status：$bugStatus",
    "- Module：$module",
    "- Selection Reason：依 STATUS.md 出現順序，選擇第一個仍為 OPEN 的 Bug",
    "- Current Phase：PLAN",
    "- Ready for PLAN：$readyForPlan",
    "",
    "## 問題摘要",
    "",
    "- Bug：$bugTitle",
    "- Impact：$impact",
    "",
    "### BUGS.md 原始規格",
    "",
    $bugSection,
    "",
    "## 修復清單",
    "",
    "- [ ] 確認 $selectedBugId 的影響範圍",
    "- [ ] 確認預計修改檔案",
    "- [ ] 產生 Root Cause Hypothesis",
    "- [ ] 產生 Repair Plan",
    "- [ ] 等待批准 IMPLEMENT",
    "- [ ] 修改後執行 Acceptance 驗證",
    "- [ ] 確認沒有修改無關檔案",
    "",
    "## Acceptance 驗收清單",
    "",
    $normalizedAcceptance,
    "",
    "## CLI 可驗證項目",
    "",
    "- [ ] npm run build：NOT_TESTED",
    "- [ ] TypeScript：NOT_TESTED",
    "- [ ] Lint：NOT_TESTED",
    "- [ ] Tests：NOT_TESTED",
    "- [ ] git diff --check：NOT_TESTED",
    "- [ ] git status：NOT_TESTED",
    "",
    "## 需要人工確認",
    "",
    "- [ ] 網頁視覺：HUMAN_CHECK_REQUIRED",
    "- [ ] 手機版排版：HUMAN_CHECK_REQUIRED",
    "- [ ] 按鈕、表單與導覽：HUMAN_CHECK_REQUIRED",
    "",
    "## Missing Information",
    "",
    $missingText,
    "",
    "## Blocking Issues",
    "",
    $blockingText,
    "",
    "## Next Required Action",
    "",
    $nextAction,
    ""
)

$report = $reportLines -join [Environment]::NewLine

[System.IO.File]::WriteAllText(
    $reportPath,
    $report,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "TODAY_CHECKLIST created successfully." -ForegroundColor Green
Write-Host "Selected Bug ID : $selectedBugId"
Write-Host "Priority        : $priority"
Write-Host "Module          : $module"
Write-Host "Ready for PLAN  : $readyForPlan"
Write-Host "Report          : $reportPath"
