# AIOS v8.1 Install Prompt

Follow AIOS Enterprise v8.1 RuntimeBridge.

Task:

Install or update AIOS runtime in the current application project.

Rules:

- Source repository is `C:\GitHub\AIOS-Enterprise`
- Target repository is current working directory
- Sync only `.aios`, `scripts`, `templates`, and `docs/runtime.md`
- Do not modify app code
- Do not modify package files
- Do not scan the whole repository

After sync, run:

```powershell
pwsh scripts/aios.ps1 doctor
git status
```

Output:

1. Source
2. Target
3. Synced paths
4. Protected paths
5. Doctor result
6. Git status summary
