# Plan: Cross-File Analyzer

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 1, Deliverables

---

## Summary

Implement `lib/src/cli/cross_file_analyzer.dart`: analysis logic that builds the import graph and exposes results for unused files, circular dependencies, and import statistics. Used by the cross-file CLI.

## Scope

- New library under `lib/src/cli/` (or equivalent) that:
  - Accepts project path and exclude globs.
  - Uses existing `ImportGraphCache` (see `lib/src/project_context_import_location.dart`) to build the import graph.
  - Exposes:
    - **Unused files:** files with no importers (e.g. `ImportGraphCache.getImporters()` or equivalent).
    - **Circular deps:** circular import chains (e.g. `ImportGraphCache.detectCircularImports()` or equivalent).
    - **Import stats:** aggregate graph statistics (e.g. `ImportGraphCache.getStats()` or equivalent).
- Integrate with the CLI entry point (`bin/cross_file.dart`) so each command calls into this module.

## Leverages

- `ImportGraphCache.getImporters()`
- `ImportGraphCache.detectCircularImports()`
- `ImportGraphCache.getStats()`

## Acceptance criteria

- [ ] Analyzer can run on a given project path with configurable exclusions.
- [ ] Results for unused files, circular dependencies, and import stats are available in a structured form for the reporter.
- [ ] No new public API required beyond what the CLI needs; can be internal to the package.

## Dependencies

- CLI entry point (`bin/cross_file.dart`) to invoke the analyzer for each command.
