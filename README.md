# AIOS Enterprise v9.2.0

Codename: Continuity

AIOS v9.2.0 adds cross-chat continuity.

## New files

- `AIOS_START.md`: startup rules for a new chat or CLI session
- `AIOS_HANDOFF.md`: human-readable project history and handoff
- `.aios/runtime/project-state.json`: machine-readable current state
- `scripts/aios-handoff.ps1`: refreshes handoff and project state

## New commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 handoff-update
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 handoff-status
```

## New chat instruction

```text
Read AIOS_START.md, AIOS_HANDOFF.md, .aios/version.json, and .aios/runtime/project-state.json first.
Continue from the recorded next action.
```
