# Changelog

## [9.1.4] - NightWatch Patch 4

### Fixed

- Fixed Windows PowerShell 5.1 null binding error for `ConvertTo-Hashtable`.
- Added `[AllowNull()]` to state conversion input.
- Prevented state reset warnings caused by `null` values such as `last_bug_id` and `updated_at`.
- Preserved duplicate fingerprint memory cleanly across polling cycles.

## [9.1.3] - NightWatch Patch 3

### Fixed

- Fixed `PSObject.Properties.Count` compatibility issue.
