# Plan: Central Stats Aggregator

**Status:** Implemented (2026-03-17). See [cross_file_cli_and_central_stats.md](cross_file_cli_and_central_stats.md).

**ROADMAP:** [Part 2: Deferred Rules & Technical Limitations](../../../ROADMAP.md) — Future Optimizations, Low effort

---

## Summary

Provide a unified API to get all cache statistics in one call. Useful for debugging and monitoring.

## Acceptance criteria

- [x] One API call returns all currently available cache statistics.
- [x] No change to analysis correctness or performance; read-only aggregation.
- [x] Documented for debugging/monitoring use.
