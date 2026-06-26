\# AIOS Runtime

# State Machine Requirement

Before any action, AI must read:

- `.ai/STATE.md`
- `.ai/12_STATE_MACHINE/STATE_MACHINE.md`

AI must obey the current phase in `.ai/STATE.md`.

If current phase is PLAN, AI must not edit code.


AI agents must follow this runtime sequence.



\## Runtime Sequence



1\. Read `.ai/START\_HERE.md`

2\. Read `.ai/11\_RUNTIME/runtime.json`

3\. Read `.ai/SPRINT.md`

4\. Select the current bug

5\. Read `.ai/module-map.json`

6\. Read mapped context file

7\. Read `.ai/token-budget.md`

8\. Read `.ai/08\_REVIEW/BUG\_REVIEW.md`

9\. Produce repair plan

10\. Wait for approval

11\. Edit code only after approval

12\. Validate

13\. Update memory and reports


## Branch Safety Check

Before editing any code, AI must check the current Git branch.

Required command:

```bash
git branch --show-current

Rules:

If current branch is main, stop immediately.
If current branch starts with feature/aios, stop immediately.
If current branch does not start with fix/, bugfix/, or hotfix/, stop and ask the human to create a proper bug branch.
AI must not edit code on AIOS framework branches.
AI must not mix AIOS framework changes with product bug fixes.

Valid examples:
fix/bug-001-booking-conflict
bugfix/appointment-time-validation
hotfix/payment-callback

\## Forbidden Before Approval



\- Global repository search

\- Editing code

\- Reading more than runtime file limit

\- Refactoring unrelated files

