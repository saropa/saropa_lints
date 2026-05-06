# Plan: Cross-File Analyzer

**Status:** Implemented (with CLI). See [IMPLEMENTED_cross_file_cli_and_central_stats.md](IMPLEMENTED_cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 1

---

## Summary

Implement analysis logic that builds the import graph and exposes unused files, circular dependencies, and stats.

## Acceptance criteria

- [x] Analyzer runs on a given project path; exclusions accepted (reserved).
- [x] Results in structured form for the reporter.
- [x] Used by `bin/cross_file.dart`.
