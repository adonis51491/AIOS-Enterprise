# AIOS Enterprise v8.0

AIOS Enterprise v8 is an AI Agent Runtime Framework for safer, faster, and more repeatable AI-assisted software development.

## Core Idea

AI should not freely scan and modify a repository.

AIOS v8 gives AI:

- Kernel
- Runtime states
- Workflow rules
- Policy guardrails
- Context routing
- Memory
- Snapshots
- Release automation
- Plugin interface

## Standard Flow

```text
PLAN → IMPLEMENT → REVIEW → VERIFY → RELEASE → ARCHIVE
```

## Quick Start

```bash
pwsh scripts/aios.ps1 doctor
pwsh scripts/aios.ps1 run BUG-001
pwsh scripts/aios.ps1 release
```

## CLI Prompt for Gemini / Codex / Claude Code

See:

```text
templates/AIOS_V8_CLI_PROMPT.md
```
