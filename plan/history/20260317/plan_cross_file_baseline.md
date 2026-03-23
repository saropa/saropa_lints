# Plan: Cross-File CLI Baseline Integration

**Status:** Implemented. See [cross_file_cli_and_central_stats.md](cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../../ROADMAP.md) — Phase 3

---

## Summary

Integrate baseline so known issues are suppressed and only new violations fail the run.

## Acceptance criteria

- [x] `--baseline <path>` loads baseline; exit 0 only if no new violations.
- [x] `--update-baseline` writes current results to baseline file.
- [x] New unused file or new cycle causes exit 1 when using baseline. JSON format documented in `CrossFileBaseline`.
