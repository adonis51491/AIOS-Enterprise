# AIOS Runtime Instructions for Codex

This repository is governed by AIOS Enterprise.

## Startup

Read these files in order when present:

1. `.aios/version.json`
2. `.aios/aios.config.yaml`
3. `.aios/kernel/kernel.yaml`
4. `.aios/runtime/runtime.yaml`
5. `.aios/policies/default.yaml`
6. `.aios/reports/TODAY_CHECKLIST.md`

## Sources of truth

- `STATUS.md` controls priority.
- `BUGS.md` controls Bug specification.
- `ACCEPTANCE.md` controls acceptance criteria.
- `.aios/reports/TODAY_CHECKLIST.md` controls the selected task.

Do not independently choose another task.

## Readiness gate

Before PLAN, verify:

- `Ready for PLAN：YES`
- one `Selected Bug ID`
- `Missing Information` is empty or `無`
- `Blocking Issues` contains no blocker

If a gate fails, stop and report it. Do not edit files.

## State machine

1. CHECKLIST
2. PLAN
3. WAIT_FOR_APPROVAL
4. IMPLEMENT
5. VALIDATE
6. REPORT

Never skip approval between PLAN and IMPLEMENT.

## PLAN

During PLAN:

- do not edit files
- do not install or upgrade packages
- do not modify `.env`, package files, or lock files
- do not scan the whole repository
- do not read full Git history
- inspect only directly relevant files
- stop after PLAN

Required output:

1. Current Branch
2. Selected Bug ID
3. Root Cause Hypothesis
4. Relevant Files
5. Repair Plan
6. Database / Security / Race-Condition Risks
7. Acceptance Mapping
8. Validation Plan
9. Missing Evidence

## IMPLEMENT

Requires explicit user approval.

- modify only files approved in PLAN
- keep changes minimal
- do not alter unrelated behavior
- do not commit or push
- stop for approval before migrations, dependency changes, `.env` changes, or expanded scope

## VALIDATE

- run the smallest relevant checks first
- record exact commands and evidence
- map every acceptance item
- use PASS, FAIL, NOT_TESTED, BLOCKED, or HUMAN_CHECK_REQUIRED
- never mark PASS without evidence

## Safety

Never do these without explicit approval:

- edit `.env`
- reveal secrets
- upgrade dependencies
- run `npm audit fix --force`
- rewrite Git history
- force-push
- delete unrelated files
- modify production infrastructure
- create a database migration
- commit or push

## Shorthand

- `AIOS PLAN`: produce PLAN only
- `AIOS IMPLEMENT`: implement the approved PLAN only
- `AIOS VALIDATE`: validate only
- `AIOS REPORT`: summarize without changing files
