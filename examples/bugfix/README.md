# Example: BUG-001 Booking Conflict

1. Copy `templates/bug/BUG-001.md` to `docs/bugs/BUG-001.md`
2. Copy `templates/bug/ACCEPTANCE-BUG-001.md` to `docs/acceptance/BUG-001.md`
3. Run:

```bash
pwsh scripts/aios.ps1 doctor
pwsh scripts/aios.ps1 run BUG-001
```

4. Paste `templates/AIOS_V8_CLI_PROMPT.md` into your AI CLI.
