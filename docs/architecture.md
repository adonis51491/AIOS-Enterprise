# AIOS v8 Architecture

AIOS v8 turns AI development from prompt-only execution into controlled runtime execution.

## Layers

```text
AIOS
├── Kernel
├── Runtime
├── Agent Manager
├── Workflow Engine
├── Policy Engine
├── Context Router
├── Memory Engine
├── Release Engine
├── Plugin SDK
└── Observatory
```

## Kernel

The Kernel controls state transitions, permissions, context limits, snapshots, and recovery.

## Runtime

The Runtime enforces a fixed execution order:

```text
PLAN → IMPLEMENT → REVIEW → VERIFY → RELEASE → ARCHIVE
```

## Agent Manager

Each agent has one job. Planner cannot edit code. Coder cannot change scope. Reviewer cannot rewrite the implementation.

## Policy Engine

Policies prevent unsafe changes such as dependency upgrades, edits to protected branches, and unrelated file modifications.
