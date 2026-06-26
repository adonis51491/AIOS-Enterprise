# AIOS Enterprise v8.1

Codename: RuntimeBridge

AIOS v8.1 turns AIOS from a copied template into a reusable runtime that can be installed, updated, and synced into application projects.

## Main Commands

```powershell
pwsh scripts/aios.ps1 doctor
pwsh scripts/aios.ps1 install -Source C:\GitHub\AIOS-Enterprise
pwsh scripts/aios.ps1 update -Source C:\GitHub\AIOS-Enterprise
pwsh scripts/aios.ps1 sync -Source C:\GitHub\AIOS-Enterprise
pwsh scripts/aios.ps1 run BUG-001
```

## Standard Usage

Keep this repository as the AIOS source:

```text
C:\GitHub\AIOS-Enterprise
```

Then install or update runtime files into app projects:

```text
C:\GitHub\energy-v2-demo
```

AIOS should manage runtime files only. It should not overwrite application code.
