# AIOS Dynamic Startup

This project uses AIOS Enterprise.

## First Action

Do not assume prior conversation context.

Always read:

```text
AIOS_HANDOFF.md
.aios/version.json
.aios/runtime/project-state.json
```

Treat these files as the source of truth for previous work, current progress, installed version, known issues, and next action.

## Version Detection

Do not assume a fixed AIOS version.

Always read:

```text
.aios/version.json
```

Use it as the single source of truth for:

- AIOS version
- Codename
- Runtime version
- Release channel
- Release summary

## Required Runtime Files

Read only what is necessary:

```text
.aios/aios.config.yaml
.aios/kernel/kernel.yaml
.aios/runtime/runtime.yaml
.aios/policies/default.yaml
.aios/workflows/
```

## Runtime Rules

- Do not scan the whole repository.
- Do not read full Git history.
- Do not install or upgrade packages without approval.
- Do not edit protected files.
- Do not modify code during PLAN.
- Stop after PLAN unless implementation is explicitly approved.

## NightWatch

Check:

```text
.aios/runtime/watch-state.json
.aios/queue/
.aios/inbox/
docs/bugs/
docs/acceptance/
```

When processing an automatic bug:

1. Select the latest queued bug.
2. Read the matching bug file.
3. Read the matching acceptance file.
4. Read the matching inbox prompt.
5. Follow the currently installed workflow.

## Startup Output

Return only:

1. Detected AIOS Version
2. Codename
3. Current Branch
4. Runtime State
5. Watcher Status
6. Latest Queued Bug
7. Previous Work Summary
8. Recommended Next Action
