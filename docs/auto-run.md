# Full Auto Repair Runtime

The full-auto repair runtime coordinates one STATUS-driven repair task at a time.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-resume
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-stop
```

## Flow

```text
STATUS.md
-> enqueue-next
-> fix/<TASK-ID>-auto
-> PLAN
-> IMPLEMENT
-> npm.cmd run build
-> git diff --check
-> commit
-> push
-> Draft PR
-> GitHub Checks and Vercel Preview
-> Ready for review
-> HUMAN_MERGE
```

`auto-run` selects the current queued task or runs `enqueue-next`, marks the task active, creates or switches to `fix/<TASK-ID>-auto`, and records PLAN and IMPLEMENT checkpoints.

`auto-resume` continues from state, validates safety, runs build and diff checks, commits, pushes, creates a draft PR, waits for checks, marks the PR ready for review when checks pass, and stops before human merge.

`auto-status` prints `.aios/runtime/auto-run-state.json`.

`auto-stop` records a stopped state without applying changes or deleting the task.

## Safety

The runtime refuses to modify `main` directly, never auto-merges, and blocks protected paths:

- `.env`
- `.env.local`
- `package.json`
- `package-lock.json`
- `pnpm-lock.yaml`
- `yarn.lock`
- Prisma migration paths
- payment provider paths or names such as PayUni and ECPay

Any build, diff, push, PR, or check failure leaves the state in `FAILED` or `WAITING_CHECKS` and requires operator action.

Every step writes `.aios/runtime/auto-run-state.json` for auditability.