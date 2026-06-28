# Semi-Auto Fix

Use this when you want AIOS to help repair bugs without giving the agent full control.

## Flow

```text
PLAN → APPROVAL → IMPLEMENT → VALIDATE → PR → HUMAN MERGE
```

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 plan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 approved
```
