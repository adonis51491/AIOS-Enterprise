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


## State Contract

`.aios/runtime/auto-run-state.json` is the canonical full-auto repair state file. The current schema stores the formal task ID at `task.id`; consumers must not read a root-level `taskId` as the primary contract.

Required fields for an active run:

- `version`: Runtime version string.
- `mode`: `full-auto-repair`.
- `phase`: Current phase, such as `QUEUED`, `BRANCH_READY`, `PLAN`, `IMPLEMENT`, `VALIDATE_BUILD`, `VALIDATE_DIFF`, `COMMITTED`, `PUSHED`, `PULL_REQUEST`, `WAITING_CHECKS`, `READY_FOR_REVIEW`, `FAILED`, or `STOPPED`.
- `task.id`: Formal `CONTEST-*` or `BUG-*` task ID.
- `task.queueFile`: Absolute queue JSON path used by the current run.
- `task.source`: STATUS.md source metadata.
- `task.files`: Relative bug, acceptance, queue, and inbox paths.
- `branch`: `fix/<TASK-ID>-auto` branch for the run.
- `safety.allowDirectMainEdits`: Always `false`.
- `safety.allowAutoMerge`: Always `false`.

Runtime readers normalize legacy state files that contain only root `taskId`, but producers must continue writing `task.id`. Legacy normalization does not change the canonical schema back to root `taskId`; it is read compatibility only and is not written back as a migration. If neither canonical `task.id` nor legacy root `taskId` is present, the runtime fails fast with a state schema error.
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