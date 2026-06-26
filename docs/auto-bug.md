# AIOS v9.0 Auto Bug

AIOS v9.0 introduces auto bug creation.

## Commands

Create a bug and acceptance file:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\aios.ps1 bug BUG-001
```

Auto-generate a timestamped bug:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\aios.ps1 bug
```

Start solve workflow:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\aios.ps1 solve
```

Start solve workflow for known bug:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\aios.ps1 solve BUG-001
```

## Files Created

```text
docs/bugs/<BUG-ID>.md
docs/acceptance/<BUG-ID>.md
```
