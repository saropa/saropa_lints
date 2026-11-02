# saropa_lints rule request: warn on `export` of another library

Status: implemented on branch `worktree-agent-a3ae8862c6431cb42` (not merged). Rule `avoid_reexports`, comprehensive tier, INFO.

## Problem
A Dart `export` directive makes one symbol importable from two libraries.
- The IDE quick-fix lists both libraries for a missing import.
- The defining file is hidden from the reader.
- Moving a symbol silently breaks or reroutes importers.

## Evidence (contacts repo)
- 129 `export` lines in 97 files.
- Example: `lib/database/drift_middleware/user_data/user_preference_drift_io.dart:11-15` re-exports five split modules, so `dbUserPreferenceSave` (defined once in `user_preference_extensions_io.dart:146`) is offered from two libraries.

## Requested rule
- Name: `avoid_reexports` (proposed).
- Fires on any `export` directive in `lib/`.
- Message: "Do not re-export. Import the defining library directly."
- Exempt: the package's public barrel file (e.g. `lib/<package>.dart`), configurable.

## Decision
Owner: re-exports are never wanted.

## Verdict
Implemented as requested: flags every `export` directive; the package entry point `lib/<package_name>.dart` is exempt (shared `_isPackageEntryPoint` helper with `avoid_barrel_files`).

Dropped: the "configurable" exemption. YAGNI; the entry-point exemption is fixed and there is no option. Comprehensive tier only because the rule is strict and opinionated.
