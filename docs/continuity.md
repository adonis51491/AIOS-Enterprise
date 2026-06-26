# AIOS Cross-Chat Continuity

AIOS v9.2.0 adds project-based continuity.

A new chat does not need the previous conversation transcript.

It reads:

```text
AIOS_START.md
AIOS_HANDOFF.md
.aios/version.json
.aios/runtime/project-state.json
```

## Update handoff state

Run after important changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 handoff-update
```

## View machine-readable state

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 handoff-status
```

## New chat opening instruction

```text
Read AIOS_START.md, AIOS_HANDOFF.md, .aios/version.json, and .aios/runtime/project-state.json first.
Continue from the recorded next action.
Do not redesign the system from scratch.
```
