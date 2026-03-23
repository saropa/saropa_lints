# Plan: GitHub Actions Example for Cross-File CLI

**Status:** Implemented (2026-03-17). See [cross_file_cli_and_central_stats.md](cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 3, Deliverables

---

## Summary

Provide a GitHub Actions example workflow that runs the cross-file CLI and fails the job when violations are found.

## Acceptance criteria

- [x] Example workflow is documented and runnable (copy into `.github/workflows/`).
- [x] No violations → exit 0; violations → exit 1. (CLI behavior; no extra flag needed.)
- [x] README links to the example: [doc/cross_file_ci_example.md](../../../doc/cross_file_ci_example.md).
