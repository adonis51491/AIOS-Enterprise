# Plugin SDK

AIOS v8 supports multiple AI tools through plugins.

Supported adapter targets:

- Gemini CLI
- Codex
- Claude Code
- Cursor
- GitHub Actions

A plugin must implement:

```text
init
plan
implement
review
verify
release
report
```
