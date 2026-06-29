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
3. Only `CONTEST-\d+` and `BUG-\d+` STATUS.md items are eligible for automatic queueing.
4. Read the generated `.aios/queue/<ID>.json`, `.aios/inbox/<ID>-PROMPT.md`, `docs/bugs/<ID>.md`, and `docs/acceptance/<ID>.md` before implementation.
5. Use `complete-current` only after validation passes.
6. Use `skip-current` only when the queued item is intentionally deferred.

Full auto repair:

1. Use `auto-run` only on a non-main branch or when it can create `fix/<TASK-ID>-auto` from main.
2. Use `auto-status` to inspect `.aios/runtime/auto-run-state.json` before resuming.
3. Use `auto-resume` only after implementation changes are present and safe to validate.
4. Use `auto-stop` to halt automation without deleting queue state.
5. Never auto-merge. Human merge remains required after checks pass and the PR is ready for review.
