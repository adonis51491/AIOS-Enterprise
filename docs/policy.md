# Policy Engine

AIOS policies protect the repository from accidental or excessive AI actions.

## Default Forbidden Actions

- Editing unrelated files
- Scanning the entire repository
- Reading full git history
- Renaming folders
- Installing packages
- Upgrading dependencies
- Editing `.env` files
- Modifying `main` or `master`

## Approval Required

- Dependency changes
- Database migrations
- Package manager lockfile changes
- CI/CD changes
