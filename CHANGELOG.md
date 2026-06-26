# Changelog

## [9.0.1] - BugHarvester Patch 1

### Fixed

- Corrected PowerShell interpolation of `${Id}:` in generated bug headings.
- Prevented `InvalidVariableReferenceWithDrive` parser failure.
- Improved positional command and target argument handling.
- Improved source path validation and copy behavior.
- `solve BUG-ID` now creates missing bug and acceptance files automatically.

### Added

- `Set-StrictMode -Version Latest`
- Doctor health status and non-zero exit code when required files are missing.
- Current Git branch is added to generated bug evidence when available.

## [9.0.0] - BugHarvester

### Added

- AIOS Daemon scaffold
- Bug Detector configuration
- Acceptance Generator configuration
- Context Builder v4 configuration
- `aios bug`
- `aios solve`
- Auto-generated bug files
- Auto-generated acceptance files
- AIOS v9 solve prompt
- Auto Bug documentation
