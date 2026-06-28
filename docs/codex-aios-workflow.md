# AIOS × Codex Workflow

AIOS is the manager. Codex is the engineer.

## Start

1. Run `aios checklist`.
2. Verify `Ready for PLAN：YES`.
3. Open Codex App in the project.
4. Type `AIOS PLAN`.
5. Review the PLAN.
6. Type `AIOS IMPLEMENT` only after approval.
7. Type `AIOS VALIDATE`.
8. Review Git diff manually.
9. Commit and push manually.

## Stop conditions

Codex must stop when:

- readiness is not YES
- acceptance is missing
- the branch does not match the task
- migration or package changes are required
- scope must expand
- secrets or production access are required
