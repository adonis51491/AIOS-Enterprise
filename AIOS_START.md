# AIOS Enterprise Start

Before working in an AIOS-managed project:

1. Read `AGENTS.md`.
2. Read `.aios/version.json`.
3. Read `.aios/runtime/runtime.json`.
4. If a queued task exists, read the queue file and its matching bug and acceptance files.
5. Use `scripts/aios-v10.ps1 enqueue-next` only when no queued or active task exists.

Runtime workflow:

```text
PLAN -> APPROVED -> IMPLEMENT -> VALIDATE -> PULL_REQUEST -> HUMAN_MERGE
```

Implementation requires explicit human approval. Do not edit `main`, `.env`, package manifests, lock files, production credentials, or production databases without approval.
