# AIOS Project Handoff

## Project

- Application repository: `C:\GitHub\energy-v2-demo`
- AIOS source repository: `C:\GitHub\AIOS-Enterprise`
- Runtime delivery model: AIOS source repository syncs runtime files into the application repository.

## Current Architecture

AIOS is separated into:

- `AIOS-Enterprise`: source runtime, scripts, templates, documentation, validation files.
- `energy-v2-demo`: application code plus the installed AIOS runtime.

The application project should not duplicate the entire AIOS source repository.

## Current Runtime Capabilities

- Dynamic version detection through `.aios/version.json`
- Runtime state machine
- Policy enforcement
- Auto bug creation
- Auto acceptance generation
- NightWatch background monitoring
- Duplicate error fingerprint protection
- Queue and inbox prompt generation
- Cross-chat project handoff

## Important File Locations

```text
AIOS_START.md
AIOS_HANDOFF.md
.aios/version.json
.aios/runtime/project-state.json
.aios/runtime/watch-state.json
.aios/queue/
.aios/inbox/
docs/bugs/
docs/acceptance/
scripts/aios.ps1
scripts/aios-watch.ps1
scripts/aios-capture.ps1
scripts/aios-service.ps1
scripts/aios-handoff.ps1
```

## Runtime Safety Rules

- PLAN must not modify application code.
- Repository-wide scanning is forbidden by default.
- Full Git history must not be read.
- Package installation or dependency upgrades require approval.
- Protected files must not be modified without approval.
- NightWatch may create bug records, acceptance files, queue records, and prompts.
- NightWatch must not silently modify application code.

## Known History

The project evolved from AIOS v8 through v9.x.

Major fixes already completed:

- PowerShell variable interpolation correction
- Windows PowerShell 5.1 JSON compatibility
- Watcher state persistence
- Duplicate error fingerprinting
- Single watcher instance locking
- Null-value state deserialization
- Cross-chat continuity

## New Chat Instructions

A new chat or CLI session must first read:

```text
AIOS_START.md
AIOS_HANDOFF.md
.aios/version.json
.aios/runtime/project-state.json
```

Then continue from the recorded next action.

Do not redesign the system from scratch unless explicitly requested.

## Maintenance

Run this command after important changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 handoff-update
```

This refreshes `.aios/runtime/project-state.json` and the generated status section in this handoff file.
