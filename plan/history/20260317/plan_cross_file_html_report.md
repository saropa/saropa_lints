# Plan: Cross-File HTML Report Generation

**Status:** Implemented. See [cross_file_cli_and_central_stats.md](cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 3

---

## Summary

Add HTML report generation for cross-file analysis.

## Acceptance criteria

- [x] `report` command with `--output-dir` (default reports). Writes index.html, unused-files.html, circular-deps.html.
- [x] Index summarizes counts and links to detail pages.
- [x] Self-contained HTML; human-readable.
