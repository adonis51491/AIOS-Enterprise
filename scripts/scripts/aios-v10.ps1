param(
  [Parameter(Position=0)][string]$Command = "help"
)
$Root = (Get-Location).Path
switch ($Command) {
  "doctor" { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "doctor.ps1") -Root $Root }
  "plan" { Get-Content (Join-Path $Root "templates/prompts/AUTO_FIX.md") -Encoding UTF8 }
  "approved" { Get-Content (Join-Path $Root "templates/prompts/AUTO_FIX_APPROVED.md") -Encoding UTF8 }
  "checklist" {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root ".aios/reports") | Out-Null
    $out = Join-Path $Root ".aios/reports/TODAY_CHECKLIST.md"
    "# TODAY_CHECKLIST`n`nReady for PLAN: YES`nBlocking Issues: Manual review required before IMPLEMENT." | Set-Content $out -Encoding UTF8
    Write-Host "Updated: $out"
  }
  default {
    Write-Host "AIOS v10 commands:"
    Write-Host "  doctor"
    Write-Host "  checklist"
    Write-Host "  plan"
    Write-Host "  approved"
  }
}
