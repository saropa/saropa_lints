# Plan: Cross-File CLI CI-Friendly Exit Codes

**Status:** Implemented (2026-03-17). See [IMPLEMENTED_cross_file_cli_and_central_stats.md](IMPLEMENTED_cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 3, Deliverables

---

## Summary

Define and implement CI-friendly exit codes for the cross-file CLI. ROADMAP: 0 = no issues, 1 = issues found, 2 = configuration error.

## Acceptance criteria

- [x] Exit 0 when the requested check finds no issues.
- [x] Exit 1 when the requested check finds one or more issues.
- [x] Exit 2 when the run cannot proceed due to bad args or config.
- [x] Documented in help and user docs.
