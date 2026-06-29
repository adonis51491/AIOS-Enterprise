# AIOS Enterprise Start

Before working in an AIOS-managed project:

1. Read `AGENTS.md`.
2. Read `.aios/version.json`.
3. Read `.aios/runtime/runtime.json`.
4. If a queued task exists, read `.aios/queue/<ID>.json`, `.aios/inbox/<ID>-PROMPT.md`, `docs/bugs/<ID>.md`, and `docs/acceptance/<ID>.md`.
5. Use `scripts/aios-v10.ps1 enqueue-next` only when no queued or active task exists.

Runtime workflow:

```text
PLAN -> APPROVED -> IMPLEMENT -> VALIDATE -> PULL_REQUEST -> HUMAN_MERGE
```

Auto queue only accepts `CONTEST-\d+` or `BUG-\d+` items from `STATUS.md`. If no eligible item exists, `enqueue-next` prints `NO_ELIGIBLE_STATUS_ITEM` and creates no files.

Implementation requires explicit human approval. Do not edit `main`, `.env`, package manifests, lock files, production credentials, or production databases without approval.