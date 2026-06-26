# AIOS Runtime

## States

| State | Purpose |
|---|---|
| INIT | Prepare runtime |
| PLAN | Analyze only specified bug and acceptance files |
| IMPLEMENT | Modify only allowed files |
| REVIEW | Review diff and risk |
| VERIFY | Compare result with acceptance criteria |
| RELEASE | Update version, changelog, release notes, commit message |
| ARCHIVE | Store report and snapshot |

## Stop Rules

AIOS must stop when:

- Scope is unclear
- Acceptance file is missing
- Policy violation is detected
- Runtime timeout is reached
- Required files are unavailable
