# Plan: Cross-File CLI Entry Point

**Status:** Implemented (2026-03-17). See [cross_file_cli_and_central_stats.md](cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 1, Deliverables

---

## Summary

Create `bin/cross_file.dart` as the CLI entry point for cross-file analysis. The executable is invoked as `dart run saropa_lints:cross_file [command] [options]`.

## Scope

- Add `bin/cross_file.dart` that:
  - Parses global options: `--path <dir>`, `--output <fmt>`, `--exclude <glob>` (repeatable).
  - Dispatches to subcommands: `unused-files`, `circular-deps`, `import-stats`.
  - Defaults: path = current directory, output = text.
- Register the executable in `pubspec.yaml` under `executables: cross_file: cross_file`.

## Acceptance criteria

- [x] `dart run saropa_lints:cross_file --help` prints usage and lists commands.
- [x] `unused-files`, `circular-deps`, `import-stats` are accepted.
- [x] `pubspec.yaml` includes `executables: cross_file: cross_file`.
