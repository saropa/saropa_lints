# Plan: Cross-File CLI Unit Tests

**Status:** Implemented. See [cross_file_cli_and_central_stats.md](cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 1

---

## Summary

Add unit tests for each command using fixture projects.

## Acceptance criteria

- [x] Fixture at `test/fixtures/cross_file_fixture/`: orphan.dart (unused), a→b→c→a (cycle).
- [x] Tests for unused-files (one unused), circular-deps (one cycle), import-stats (4 files, 3 imports).
- [x] Tests pass; fixture excluded from analysis via `analysis_options.yaml`.
