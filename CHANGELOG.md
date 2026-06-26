# Changelog

## Unreleased

### Added

- Daily Bug checklist generator
- STATUS → BUGS → ACCEPTANCE routing
- Automatic Bug priority selection
- Bug-specific acceptance extraction
- UTF-8 compatible PowerShell processing
- `aios checklist` command
- Checklist template and documentation

### Fixed

- Acceptance parser no longer captures unrelated sections
- Bug parser supports Traditional Chinese Markdown
- PowerShell output uses UTF-8 encoding

## [9.2.0] - Continuity

### Added

- Dynamic startup file for new chats
- Human-readable project handoff
- Machine-readable project state
- Automatic handoff updater
- `handoff-update`
- `handoff-status`
- Cross-chat continuity documentation

### Changed

- New sessions no longer depend on the previous chat transcript.
- Version detection remains dynamic through `.aios/version.json`.

## [9.1.4] - NightWatch Patch 4

### Fixed

- Null-value state deserialization in Windows PowerShell 5.1.
