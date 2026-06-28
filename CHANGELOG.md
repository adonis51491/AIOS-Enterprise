# Changelog

## 10.0.2

### Fixed
- Removed invalid leading backslash before PowerShell `param` blocks.
- Added strict parameter validation.
- Made installer and doctor resolve paths from their script location.
- Prevented duplicate `scripts/scripts`, `docs/docs`, and `templates/templates` nesting.
- Installer now stops on errors instead of printing a false success message.
