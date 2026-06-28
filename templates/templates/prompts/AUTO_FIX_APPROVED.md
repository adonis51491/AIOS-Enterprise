# AIOS SEMI-AUTO FIX — APPROVED IMPLEMENTATION

The previous PLAN is approved.

## Required Flow

1. Confirm the selected Bug ID from the approved PLAN.
2. Confirm current branch is `fix/auto-<BUG-ID>` or another approved `fix/` branch.
3. Modify only files listed in the approved PLAN.
4. Do not process any other bug.
5. Do not modify `.env`, `package.json`, lock files, `.gitignore`, or migrations unless explicitly listed in the approved PLAN.
6. Run validation:
   - `npm.cmd run build`
   - `git diff --check`
7. If validation fails, stop and report.
8. If validation passes, prepare commit and PR.
9. Do not merge.

## Final Output Format

1. Selected Bug ID
2. Modified Files
3. Change Summary
4. Validation Result
5. Commit SHA if committed
6. Push Result if pushed
7. PR Link if created
8. Remaining Risks
9. Human Review Needed
