# Plan: Cross-File Reporter

**Status:** Implemented (2026-03-17). See [IMPLEMENTED_cross_file_cli_and_central_stats.md](IMPLEMENTED_cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 1, Deliverables

---

## Summary

Implement `lib/src/cli/cross_file_reporter.dart`: output formatting for cross-file analysis results. Supports text (default) and JSON formats as specified in ROADMAP Phase 1.3.

## Acceptance criteria

- [x] Text and JSON formats match the ROADMAP examples (or documented variant).
- [x] Reporter is used by the CLI based on `--output` option.
- [x] Output is deterministic and easy to parse (e.g. CI).
