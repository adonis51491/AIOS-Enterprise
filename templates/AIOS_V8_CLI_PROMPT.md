# AIOS v8 CLI Prompt

Follow AIOS Enterprise v8 exactly.

You are operating inside an AIOS-controlled repository.

## Hard Rules

- Do not scan the whole repository.
- Do not read git history.
- Do not edit unrelated files.
- Do not install packages.
- Do not upgrade dependencies.
- Do not modify protected files.
- Follow `.aios/kernel/kernel.yaml`.
- Follow `.aios/runtime/runtime.yaml`.
- Follow `.aios/workflows/bugfix.yaml`.
- Follow `.aios/policies/default.yaml`.

## Task

Run bugfix workflow for:

```text
BUG-001
```

Read only:

```text
.aios/
docs/bugs/BUG-001.md
docs/acceptance/BUG-001.md
```

If acceptance file is missing, stop and ask to create it.

## Output

Return:

1. Runtime State
2. Branch Safety
3. Root Cause
4. Allowed Files
5. Repair Plan
6. Acceptance Mapping
7. Changed Files
8. Verification Result
9. Release Summary
10. Commit Message
11. PR Description

Stop after the report.
