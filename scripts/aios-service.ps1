param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet("install", "start", "stop", "status", "uninstall", "run-once")]
  [string]$Command,

  [string]$ProjectRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Get-Location).Path
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$TaskName = "AIOS-NightWatch-" + (($ProjectRoot -replace '[^A-Za-z0-9]', '_').Trim('_'))
$WatcherScript = Join-Path $ProjectRoot "scripts\aios-watch.ps1"
$PowerShellExe = (Get-Command powershell.exe).Source

function Get-Task {
  Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
}

switch ($Command) {
  "install" {
    if (-not (Test-Path -LiteralPath $WatcherScript)) {
      throw "Watcher script not found: $WatcherScript"
    }

    $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WatcherScript`" -ProjectRoot `"$ProjectRoot`""
    $action = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $arguments -WorkingDirectory $ProjectRoot
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "AIOS v9.1 NightWatch for $ProjectRoot" -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName

    Write-Host "Installed and started: $TaskName" -ForegroundColor Green
  }

  "start" {
    if (-not (Get-Task)) { throw "Task is not installed. Run install first." }
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Started: $TaskName" -ForegroundColor Green
  }

  "stop" {
    if (-not (Get-Task)) { throw "Task is not installed." }
    Stop-ScheduledTask -TaskName $TaskName
    Write-Host "Stopped: $TaskName" -ForegroundColor Yellow
  }

  "status" {
    $task = Get-Task
    if (-not $task) {
      Write-Host "NOT INSTALLED: $TaskName" -ForegroundColor Red
      exit 1
    }

    $info = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host "Task: $TaskName"
    Write-Host "State: $($task.State)"
    Write-Host "Last run: $($info.LastRunTime)"
    Write-Host "Last result: $($info.LastTaskResult)"
  }

  "uninstall" {
    if (Get-Task) {
      Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    Write-Host "Uninstalled: $TaskName" -ForegroundColor Green
  }

  "run-once" {
    & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $WatcherScript -ProjectRoot $ProjectRoot -Once
  }
}
