# Not Viable: `require_drift_wal_mode`

## Status: NOT VIABLE

## Proposed Rule
Warn when `PRAGMA journal_mode = WAL` is not set on NativeDatabase.

## Why Not Viable
**Handled automatically by drift_flutter.** The `driftDatabase()` function from `drift_flutter` sets WAL mode automatically on supported platforms. Requiring it manually would false-positive on projects using `drift_flutter` (the recommended setup). Additionally, WAL mode is a performance optimization typically set once at database creation, not a common source of bugs.

## Category
Automatically handled — `drift_flutter` manages this.
