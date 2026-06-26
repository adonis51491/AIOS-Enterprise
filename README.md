# AIOS Enterprise v9.1

Codename: NightWatch

AIOS v9.1 adds unattended error monitoring and automatic bug documentation.

## Background setup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 watch-install
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios.ps1 watch-status
```

## Run monitored commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-capture.ps1 console npm run dev
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-capture.ps1 test npm test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-capture.ps1 build npm run build
```

When an error is detected, AIOS automatically creates bug, acceptance, queue, and prompt files.
