# Auto Queue Runtime

The v10 auto queue turns the next eligible `STATUS.md` item into one isolated AIOS task.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 enqueue-next
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 queue-status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 current
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 complete-current
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 skip-current
```

## Eligible STATUS.md Items

`enqueue-next` prioritizes sections named `Current Sprint`, `&#x5DE5;&#x4F5C;&#x9806;&#x5E8F;`, or `&#x660E;&#x78BA;&#x6392;&#x5E8F;&#x6E05;&#x55AE;`. If none exist, it scans `STATUS.md` from top to bottom.

Only items with one of these formal IDs can be queued:

- `CONTEST-\d+`
- `BUG-\d+`

The selected task keeps the exact formal ID from `STATUS.md`, such as `CONTEST-001`. AIOS never creates fallback IDs such as `BUG-<date>-status-item`.

Completed or deferred lines are skipped when they contain `DONE`, `COMPLETED`, `CLOSED`, `SKIPPED`, or `[x]`.

If no eligible item exists, `enqueue-next` prints `NO_ELIGIBLE_STATUS_ITEM` and creates no files.

## Output Contract

For each eligible task, `enqueue-next` creates or references:

- `docs/bugs/<ID>.md`
- `docs/acceptance/<ID>.md`
- `.aios/queue/<ID>.json`
- `.aios/inbox/<ID>-PROMPT.md`

`docs/bugs/<ID>.md` and `docs/acceptance/<ID>.md` are never overwritten. If either file already exists, the queue JSON and inbox prompt reference the existing document.

`enqueue-next` refuses to create a new task when any `.aios/queue/*.json` file is still `queued` or `active`.

`complete-current` marks the queue item completed and marks the source `STATUS.md` line as `[x]` for checklist items or appends `DONE` for ordered items.

`skip-current` marks the queue item skipped and marks the source `STATUS.md` line as `[-]` for checklist items or appends `SKIPPED` for ordered items.
