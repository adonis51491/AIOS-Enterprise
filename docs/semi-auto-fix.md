# Semi-Auto Fix Workflow

1. NightWatch or a human creates a queued bug.
2. Run `scripts\aios-v10.ps1 plan`.
3. Paste the resulting prompt into Codex.
4. Review the plan.
5. Run `scripts\aios-v10.ps1 approved`.
6. Codex implements and validates.
7. Create and review a Pull Request.
8. Merge manually.
