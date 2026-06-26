# AIOS v8.1 Installer

AIOS v8.1 adds a reusable installer and updater.

## Goal

AIOS-Enterprise becomes the source runtime repository.

Application projects such as `energy-v2-demo` only install or update the runtime.

## Install into a project

From the target project:

```powershell
pwsh C:\GitHub\AIOS-Enterprise\scripts\aios.ps1 install -Source C:\GitHub\AIOS-Enterprise
```

## Update an existing project

```powershell
pwsh scripts\aios.ps1 update -Source C:\GitHub\AIOS-Enterprise
```

## Sync only runtime files

```powershell
pwsh scripts\aios.ps1 sync -Source C:\GitHub\AIOS-Enterprise
```

## What gets synced

- `.aios/`
- `scripts/`
- `templates/`
- `docs/runtime.md`

## What is protected

- `.git/`
- `node_modules/`
- `.env`
- `.env.local`
- package manager lockfiles
