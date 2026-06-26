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

