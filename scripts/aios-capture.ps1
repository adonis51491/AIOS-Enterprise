param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet("console", "test", "build")]
  [string]$Channel,

  [Parameter(Mandatory = $true, Position = 1, ValueFromRemainingArguments = $true)]
  [string[]]$Command
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Location).Path
$LogDir = Join-Path $ProjectRoot ".aios\logs"
if (-not (Test-Path -LiteralPath $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$LogPath = Join-Path $LogDir "$Channel.log"
$commandText = $Command -join " "

Add-Content -LiteralPath $LogPath -Value "`n===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') :: $commandText =====" -Encoding UTF8

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = "/d /s /c `"$commandText`""
$psi.WorkingDirectory = $ProjectRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $false

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi

$handler = {
  if (-not [string]::IsNullOrWhiteSpace($EventArgs.Data)) {
    $EventArgs.Data | Tee-Object -FilePath $using:LogPath -Append
  }
}

$process.add_OutputDataReceived($handler)
$process.add_ErrorDataReceived($handler)

[void]$process.Start()
$process.BeginOutputReadLine()
$process.BeginErrorReadLine()
$process.WaitForExit()

exit $process.ExitCode
