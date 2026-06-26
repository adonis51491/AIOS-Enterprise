\# AIOS State Machine



AI must work in phases.



\## Phase 1: PLAN



Goal:

Understand the task and produce a repair plan.



Allowed:

\- Read AIOS files

\- Read mapped files

\- Produce plan



Forbidden:

\- Edit code

\- Commit

\- Push



Exit condition:

Human approves the repair plan.



\---



\## Phase 2: EDIT



Goal:

Implement the approved fix.



Allowed:

\- Edit approved files only

\- Keep scope small



Forbidden:

\- Refactor unrelated code

\- Change unrelated modules

\- Commit

\- Push



Exit condition:

Implementation is complete.



\---



\## Phase 3: VERIFY



Goal:

Validate the fix.



Required:

\- npm run build

\- git diff --check



Optional:

\- Playwright tests

\- Manual browser test



Exit condition:

Validation result is reported.



\---



\## Phase 4: REPORT



Goal:

Update AIOS memory and report.



Required:

\- Update .ai/09\_MEMORY/SESSION.md

\- Create or update .ai/10\_REPORTS bugfix report

\- Suggest BUGS.md / STATUS.md updates



Exit condition:

Human approves final changes.



\---



\## Phase 5: COMMIT



Goal:

Prepare Git commit and PR summary.



Allowed:

\- Suggest commit message

\- Suggest PR summary



Forbidden:

\- Commit unless human explicitly approves

\- Push unless human explicitly approves

