# Changelog

## [0.1.0] - 2025-03-14

### Added

- Master on/off switch (`saropaLints.enabled`). When on, extension sets up pubspec and analysis_options.
- Enable command: adds saropa_lints to dev_dependencies, runs pub get, runs init with selected tier, optionally runs analysis.
- Run Analysis, Initialize Config, Open Config, Repair Config, Set Tier commands.
- **Views:** Issues (by file, click to open at line), Summary (totals, by severity, by impact), Config (settings + quick actions), Logs (reports/ logs, open on click), Suggestions (what to do next).
- viewsWelcome when disabled or no analysis yet.
- Status bar: Saropa Lints On/Off.
- File watcher on `reports/.saropa_lints/violations.json` to refresh views when analysis completes.
- Output channel "Saropa Lints" for init/analyze command output.
- Cursor-compatible engine (`^1.74.0`).
