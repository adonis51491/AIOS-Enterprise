## v6.8.0

Date: 2026-06-27

Codename: Runtime Intelligence

### Summary

Automated release generated from recent Git commits.

### Recent Changes

chore(release): bump AIOS version feat(aios): add automated release metadata command feat(aios): add runtime state machine feat(aios): add branch safety runtime feat(aios): add runtime optimization and memory engine feat(aios): add context routing and review gate feat: add AIOS v6.2 CLI and v6.4 runtime prompts feat: harden AIOS installer docs: add AIOS Enterprise v6.1.1 documentation foundation feat: create AIOS Enterprise v6.1 installer framework

---
## v6.7.1

Date: 2026-06-27

### Added / Changed

- Add automated version and changelog update command

---
## v6.7.1

Date: 2026-06-27

### Added / Changed

- Add automated version and changelog update command

---
\# Changelog

## v6.7.0

### Added

- AIOS State file
- Runtime State Machine
- Phase-based workflow: PLAN, EDIT, VERIFY, REPORT, COMMIT

### Changed

- AI agents must obey current phase before taking action
- PLAN phase now forbids editing code

---


## v6.6.1

### Added

- Branch Safety Runtime
- Required branch check before editing
- Forbidden editing on main or AIOS framework branches
- Allowed bugfix branch prefixes

### Changed

- Runtime now prevents mixing AIOS framework changes with product bug fixes

---


## v6.6.0

### Added

- Runtime configuration
- AI Runtime sequence
- Session Memory
- Decision Memory
- Architecture Memory
- Bugfix report template

### Changed

- AI agents must follow runtime sequence before editing
- AI agents must update memory and reports after work
- Context routing is now part of the runtime

---


## v6.5.0

### Added

- Context Routing Rule
- Token Budget Rules
- Module Map
- Appointment Context
- Bug Review Gate

### Changed

- AI agents must read mapped context files before searching globally
- AI agents must pass review gate before editing code

---


\## v6.1.2



\### Added



\- Installer environment checks

\- Existing `.ai` backup before install

\- Installation log

\- Installed version file `.aios-version.json`



\### Changed



\- Improved `install.ps1` reliability and feedback



\---



\## v6.1.1



\### Added



\- Documentation structure

\- Changelog

\- Project installation guide

\- AIOS Enterprise roadmap



\### Changed



\- Preparing template structure for reusable installation



\---



\## v6.1.0



\### Added



\- Initial AIOS Enterprise installer framework

\- Template folder

\- install.ps1

\- version.json

\- README.md




