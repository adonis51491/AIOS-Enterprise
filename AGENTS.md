# AIOS Enterprise v10.0.2

Before project work:

1. Read `.aios/version.json`.
2. Read `.aios/runtime/runtime.json`.
3. Read the newest queued bug and its matching bug and acceptance files.
4. PLAN must not modify files.
5. IMPLEMENT requires explicit human approval.
6. Never edit `main`, `.env`, package manifests, lock files, production credentials, or production databases without approval.
7. Validate before commit.
8. Open a PR; never merge automatically.

Auto queue:

1. Use `scripts/aios-v10.ps1 queue-status` and `scripts/aios-v10.ps1 current` to inspect queued work.
2. Use `scripts/aios-v10.ps1 enqueue-next` only when no queued or active task exists.
3. Read the generated queue, bug, inbox, and acceptance files before implementation.
4. Use `complete-current` only after validation passes.
5. Use `skip-current` only when the queued item is intentionally deferred.
