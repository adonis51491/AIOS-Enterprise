# Changelog

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
