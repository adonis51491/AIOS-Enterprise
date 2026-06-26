# AIOS Enterprise v9.0.1

Codename: BugHarvester Patch 1

This patch fixes the PowerShell parser error found in v9.0 and strengthens the runtime script.

## Verify

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 doctor
```

## Generate Bug and Acceptance

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 bug BUG-001
```

## Start Solve Workflow

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 solve BUG-001
```

The solve command creates missing bug and acceptance files, then prepares the AI CLI workflow.
