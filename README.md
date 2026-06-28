# AIOS Enterprise v9.2.1 — Semi-Auto Fix

This package adds a guarded semi-automatic repair workflow for AIOS + Codex.

## Flow

```text
NightWatch / Queue
→ Semi-Auto PLAN
→ Human APPROVED
→ Codex IMPLEMENT
→ Build / diff check
→ Commit + Push
→ Pull Request
→ Human Merge
```

## Safety Defaults

- Never edit `main`.
- Never merge automatically.
- Never modify `.env`, package files, lock files, or `.gitignore` without explicit approval.
- Never process unrelated bugs.
- Always stop after PLAN until human approval.
- Always create PR for review.

## Main Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-semi-auto.ps1 plan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-semi-auto.ps1 implement
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-semi-auto.ps1 validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\aios-semi-auto.ps1 pr
```
