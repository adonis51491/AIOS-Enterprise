# AIOS v9.1 NightWatch

NightWatch runs in the background and watches AIOS log files.

## What it does automatically

When a matching error appears in:

- `.aios/logs/console.log`
- `.aios/logs/test.log`
- `.aios/logs/build.log`

NightWatch automatically creates:

- `docs/bugs/BUG-AUTO-<timestamp>.md`
- `docs/acceptance/BUG-AUTO-<timestamp>.md`
- `.aios/queue/BUG-AUTO-<timestamp>.json`
- `.aios/inbox/BUG-AUTO-<timestamp>-PROMPT.md`

It also deduplicates repeated errors using a fingerprint.

## Install background watcher

Run PowerShell as Administrator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 watch-install
```

## Check watcher status

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 watch-status
```

## Capture commands into monitored logs

Development server:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-capture.ps1 console npm run dev
```

Tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-capture.ps1 test npm test
```

Build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-capture.ps1 build npm run build
```

## Important limit

NightWatch automatically detects and documents errors, but it does not silently modify application code. It prepares a queued bug and a ready-to-paste AI CLI prompt. This prevents unattended code changes while you are away.
