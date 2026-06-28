# AIOS SEMI-AUTO FIX

You are running AIOS Semi-Auto Fix.

## Goal

Process the latest queued bug and reduce human back-and-forth.

## Required Flow

1. Read `.aios/version.json`.
2. Read `.aios/aios.config.yaml` if present.
3. Read `.aios/runtime/runtime.yaml` if present.
4. Read `.aios/policies/default.yaml` if present.
5. Find the latest file in `.aios/queue/`.
6. Read the matching `docs/bugs/<BUG-ID>.md`.
7. Read the matching `docs/acceptance/<BUG-ID>.md`.
8. Read the matching `.aios/inbox/<BUG-ID>-PROMPT.md` if present.
9. Check current branch.
10. If on `main`, stop.
11. Create or switch to `fix/auto-<BUG-ID>`.
12. Output PLAN only.
13. Stop and wait for the exact human approval keyword: `APPROVED`.

## PLAN Output Format

1. AIOS Version
2. Current Branch
3. Selected Bug ID
4. Bug Summary
5. Acceptance Criteria
6. Files Proposed for Read
7. Files Proposed for Modification
8. Repair Plan
9. Validation Plan
10. Risks
11. Approval Needed

## Forbidden During PLAN

- Do not modify files.
- Do not run destructive commands.
- Do not install or upgrade packages.
- Do not commit.
- Do not push.
- Do not merge.
- Do not scan the whole repository.
