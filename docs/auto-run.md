# Full Auto Repair Runtime

The full-auto repair runtime coordinates one STATUS-driven repair task at a time.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-resume
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 auto-stop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 finalize-completed-state
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
-> complete-current
-> COMPLETED terminal state
```

`auto-run` selects the current queued task or runs `enqueue-next`, marks the task active, creates or switches to `fix/<TASK-ID>-auto`, and records PLAN and IMPLEMENT checkpoints.

`auto-resume` continues from state, validates safety, runs build and diff checks, commits, pushes, creates a draft PR, waits for checks, marks the PR ready for review when checks pass, and stops before human merge.

`complete-current` marks the current queue item completed, updates `STATUS.md`, and finalizes the matching auto-run state as `COMPLETED` when a matching state file exists. The state finalization preserves history and writes `active=false`, `task.status=completed`, `completedAt`, and `stopReason=TASK_COMPLETED`.

`finalize-completed-state` is the audited recovery path for legacy stale states where the queue item is already completed but `.aios/runtime/auto-run-state.json` still contains an active phase for the same task. It validates the matching queue item and completion metadata before converting the state to `COMPLETED`. Do not manually delete the state file.

`auto-status` prints `.aios/runtime/auto-run-state.json`.

`auto-stop` records a stopped terminal state without applying changes or deleting the task.

## State Contract

`.aios/runtime/auto-run-state.json` is the canonical full-auto repair state file. The current schema stores the formal task ID at `task.id`; consumers must not read a root-level `taskId` as the primary contract.

Required fields for a canonical run:

- `schemaVersion`: Runtime state schema version.
- `version`: Runtime version string.
- `mode`: `full-auto-repair`.
- `phase`: Current lifecycle phase.
- `active`: Boolean. `true` means this state blocks another auto-run; `false` means terminal.
- `task.id`: Formal `CONTEST-*` or `BUG-*` task ID.
- `task.queueFile`: Absolute queue JSON path used by the current run.
- `task.source`: STATUS.md source metadata.
- `task.files`: Relative bug, acceptance, queue, and inbox paths.
- `branch`: `fix/<TASK-ID>-auto` branch for the run.
- `safety.allowDirectMainEdits`: Always `false`.
- `safety.allowAutoMerge`: Always `false`.

Active phases block starting another auto-run:

- `STARTED`
- `QUEUED`
- `BRANCH_READY`
- `PLAN`
- `IMPLEMENT`
- `VALIDATE_BUILD`
- `VALIDATE_DIFF`
- `COMMITTED`
- `PUSHED`
- `PULL_REQUEST`
- `WAITING_CHECKS`
- `READY_FOR_REVIEW`

Terminal phases do not block starting the next task:

- `COMPLETED`
- `FAILED`
- `STOPPED`
- `BLOCKED`

A completed terminal state must include:

- `phase=COMPLETED`
- `active=false`
- `task.status=completed`
- `completedAt` as an ISO-8601 UTC timestamp
- `stopReason=TASK_COMPLETED`
- preserved historical `events`
- one `COMPLETED` event

Malformed state fails closed. Missing phase, missing task ID, unknown phase, or mismatched state/task completion is rejected rather than ignored.

Runtime readers normalize legacy state files that contain only root `taskId`, but producers must continue writing `task.id`. Legacy normalization does not change the canonical schema back to root `taskId`; it is read compatibility only and is not written back as a migration. If neither canonical `task.id` nor legacy root `taskId` is present, the runtime fails fast with a state schema error.

## Stale Completed-State Recovery

Use this command only when the queue item for the state task is already completed and the state file still shows an active phase for the same task:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-v10.ps1 finalize-completed-state -Root <project-root>
```

The command verifies:

- the state task ID exists
- the matching queue item exists
- the queue status is `completed`
- queue completion metadata is present
- the state has no unfinished commit, push, PR, or waiting-check events

When validation passes, the command converts the state to `COMPLETED` and leaves queued, blocked, and unrelated task artifacts unchanged. Running it again is a safe no-op for an already completed state.

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
