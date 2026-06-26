# AIOS v9.0 Solve Prompt

Follow AIOS Enterprise v9.0 BugHarvester.

You are operating under AIOS Kernel control.

## Goal

Automatically create or use a bug record, generate acceptance criteria, build context, and stop after PLAN unless explicitly asked to implement.

## Read only first

```text
.aios/
docs/bugs/
docs/acceptance/
.aios/logs/console.log
.aios/logs/test.log
.aios/logs/build.log
```

## Hard Rules

- Do not scan the whole repository.
- Do not read git history.
- Do not install packages.
- Do not upgrade dependencies.
- Do not modify package files.
- Do not edit app code during PLAN.
- If a bug file is missing, generate a bug draft first.
- If an acceptance file is missing, generate acceptance criteria first.
- Stop after PLAN.

## Output only

1. Runtime State
2. Detected / Selected Bug ID
3. Generated Bug Summary
4. Generated Acceptance Criteria
5. Context Summary
6. Allowed Files
7. Root Cause
8. Repair Plan
9. Acceptance Mapping
10. Stop Reason
