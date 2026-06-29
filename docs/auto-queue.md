# Auto Queue Runtime

The v10 auto queue turns the first incomplete `STATUS.md` checklist item into one isolated AIOS task.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 enqueue-next
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 queue-status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 current
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 complete-current
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 skip-current
```

## Behavior

`enqueue-next` reads the target project's `STATUS.md` and selects the first unchecked checklist item:

```markdown
- [ ] Example task
```

It refuses to create a new task when any `.aios/queue/*.json` file is still `queued` or `active`.

For each task it creates:

- `.aios/bugs/<id>.md`
- `.aios/acceptance/<id>.md`
- `.aios/queue/<id>.json`
- `.aios/inbox/<id>.md`

Existing files are never overwritten.

`complete-current` marks the queue item completed and changes the source `STATUS.md` line to `[x]`.

`skip-current` marks the queue item skipped and changes the source `STATUS.md` line to `[-]`, allowing the next unchecked item to be queued.
