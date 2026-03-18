# Implemented: Cross-File CLI and Central Stats Aggregator (2026-03-17)

**Plans implemented:** `plan_cross_file_cli_entry_point`, `plan_cross_file_reporter`, `plan_central_stats_aggregator` (from `bugs/plan/`).

## Summary

1. **Cross-file CLI entry point** — `bin/cross_file.dart` parses `--path`, `--output` (text|json), `--exclude` (reserved), and commands `unused-files` / `circular-deps` / `import-stats`. Registered in `pubspec.yaml` as `cross_file`. Exit codes 0/1/2. Shows "Building import graph..." on stderr before analysis.

2. **Cross-file reporter** — `lib/src/cli/cross_file_reporter.dart`: `CrossFileResult` and `CrossFileReporter.report()` for text and JSON output. Used by the CLI.

3. **Central Stats Aggregator** — `lib/src/project_context_cache_stats.dart` (part of `project_context`): `CacheStatsAggregator.getStats()` returns one map aggregating all cache statistics (import graph, throttle, speculative, rule batch, baseline, semantic, etc.) for debugging/monitoring.

**Supporting:** `lib/src/cli/cross_file_analyzer.dart` (builds graph, computes unused files and cycles); `ImportGraphCache.getFilePaths()` in `project_context_import_location.dart`; unit tests in `test/cli/cross_file_test.dart`. README and CHANGELOG updated.
