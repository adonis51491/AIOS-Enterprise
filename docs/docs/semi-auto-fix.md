# AIOS Semi-Auto Fix Workflow

## Purpose

Use this workflow when you want future bugs to be handled with less back-and-forth, while still keeping human approval before code changes and before merge.

## Standard Flow

1. Read latest queue item from `.aios/queue/`.
2. Read matching `docs/bugs/<BUG-ID>.md`.
3. Read matching `docs/acceptance/<BUG-ID>.md`.
4. Read matching `.aios/inbox/<BUG-ID>-PROMPT.md` when available.
5. Create or switch to `fix/auto-<BUG-ID>`.
6. Produce PLAN only.
7. Wait for human approval.
8. Implement only approved files.
9. Run validation.
10. Commit, push, and open PR.
11. Never merge automatically.

## Human Approval Keyword

```text
APPROVED
```

## Required Validation

```powershell
npm.cmd run build
git diff --check
```

## Forbidden Without Explicit Approval

- `.env`
- `package.json`
- lock files
- `.gitignore`
- database migration
- production secrets
- direct merge to main
