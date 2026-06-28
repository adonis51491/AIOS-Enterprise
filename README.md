# AIOS Enterprise v10.0.2

Semi-automatic bug repair runtime:

`detect → queue → plan → approval → implement → validate → PR → human merge`

Main commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 doctor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 plan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 approved
```
