# AIOS Enterprise v11 — Governed Engineering Orchestrator

AIOS v11 changes the system from a Markdown-driven automation runtime into a governed engineering orchestrator.

## Core contract

The machine-readable task file is the single source of truth:

```text
.aios-data/tasks/<TASK-ID>.json
```

Markdown status documents are generated views. They are not authoritative task databases.

## State machine

Allowed non-terminal flow:

```text
QUEUED
→ PLANNING
→ WAITING_APPROVAL
→ IMPLEMENTING
→ VALIDATING
→ PR_READY
→ WAITING_MERGE
→ COMPLETED
```

Terminal states:

```text
COMPLETED
BLOCKED
FAILED
CANCELLED
SKIPPED
```

State changes must pass through the `transition` command. Direct JSON editing is unsupported.

## Approval binding

A plan is recorded with a SHA-256 digest:

```powershell
.\scripts\aios-v11.ps1 plan-record `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -PlanPath docs\plans\BUG-001.md
```

Approval must include the exact digest:

```powershell
.\scripts\aios-v11.ps1 approve `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -PlanHash <SHA256>
```

Changing the plan invalidates the previous approval.

## Evidence bundle

Validation results are recorded with:

- check name
- exact command
- exit code
- result
- branch
- commit SHA
- timestamp
- optional notes

Evidence is stored both inside the task record and as an immutable-style bundle under:

```text
.aios-data/evidence/<TASK-ID>/
```

A task cannot enter `PR_READY` without at least one passing evidence record.

## One active task rule

Only one non-terminal task may exist at a time. Terminal tasks remain available for audit and reporting.

## Doctor checks

The v11 doctor checks:

- readable task JSON
- duplicate task IDs
- unknown states
- more than one non-terminal task
- stale plan approvals
- incomplete evidence records
- common nested duplicate deployment directories

## Typical workflow

```powershell
.\scripts\aios-v11.ps1 init -Root C:\GitHub\project

.\scripts\aios-v11.ps1 task-create `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -Title "Prevent duplicate booking"

.\scripts\aios-v11.ps1 transition `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -To PLANNING

.\scripts\aios-v11.ps1 plan-record `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -PlanPath docs\plans\BUG-001.md

.\scripts\aios-v11.ps1 approve `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -PlanHash <SHA256>

.\scripts\aios-v11.ps1 transition `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -To IMPLEMENTING
```

After implementation:

```powershell
.\scripts\aios-v11.ps1 transition -Root C:\GitHub\project -TaskId BUG-001 -To VALIDATING

.\scripts\aios-v11.ps1 evidence-record `
  -Root C:\GitHub\project `
  -TaskId BUG-001 `
  -CheckName build `
  -CheckCommand "npm.cmd run build" `
  -ExitCode 0 `
  -CommitSha <commit> `
  -Branch fix/BUG-001

.\scripts\aios-v11.ps1 transition -Root C:\GitHub\project -TaskId BUG-001 -To PR_READY
```

## Migration from v10

v10 remains available for compatibility. v11 does not automatically import queue or runtime state because silent conversion could incorrectly preserve stale or contradictory state.

Recommended migration:

1. Finish or close the current v10 task.
2. Run `init` for the target project.
3. Create one v11 task from the verified current work item.
4. Preserve old v10 files as a read-only archive.
5. Generate human-readable status using `render-status`.

## Safety position

AIOS v11 may prepare work and evidence, but it does not auto-merge. Environment files, production credentials, destructive database operations, package upgrades, and deployment changes still require explicit task scope and human approval.
