# Implemented: Cross-File CLI and Central Stats Aggregator (2026-03-17)

**Plans implemented:** `plan_cross_file_cli_entry_point`, `plan_cross_file_reporter`, `plan_central_stats_aggregator` (from `bugs/plan/`).

## Summary

1. **Cross-file CLI entry point** — `bin/cross_file.dart` parses `--path`, `--output` (text|json), `--exclude` (reserved), and commands `unused-files` / `circular-deps` / `import-stats`. Registered in `pubspec.yaml` as `cross_file`. Exit codes 0/1/2. Shows "Building import graph..." on stderr before analysis.

2. **Cross-file reporter** — `lib/src/cli/cross_file_reporter.dart`: `CrossFileResult` and `CrossFileReporter.report()` for text and JSON output. Used by the CLI.

3. **Central Stats Aggregator** — `lib/src/project_context_cache_stats.dart` (part of `project_context`): `CacheStatsAggregator.getStats()` returns one map aggregating all cache statistics (import graph, throttle, speculative, rule batch, baseline, semantic, etc.) for debugging/monitoring.

**Supporting:** `lib/src/cli/cross_file_analyzer.dart` (builds graph, computes unused files and cycles); `ImportGraphCache.getFilePaths()` in `project_context_import_location.dart`; unit tests in `test/cli/cross_file_test.dart`. README and CHANGELOG updated.

---

## Later (same session): CI exit codes, README, GitHub Actions example

4. **CI exit codes** — Already implemented: `bin/cross_file.dart` exits 0 (no issues), 1 (issues found), 2 (config error). Documented in `--help` and README.

5. **README** — Cross-file section expanded: `--exclude` (reserved) in options, JSON-to-file example, link to CI example doc.

6. **GitHub Actions example** — `doc/cross_file_ci_example.md`: copy-paste workflow that runs `unused-files` and `circular-deps`, with optional JSON output and artifact upload. README links to it.

---

## Remaining plans (all four implemented)

7. **Cross-file analyzer** — Already implemented: `lib/src/cli/cross_file_analyzer.dart` used by the CLI.

8. **Unit tests** — Fixture at `test/fixtures/cross_file_fixture/` (orphan + cycle a→b→c→a). Tests assert one unused file (orphan.dart), one cycle, 4 files and 3 imports. Path normalization in `ImportGraphCache._parseImports` for consistent graph keys on Windows.

9. **Baseline** — `lib/src/cli/cross_file_baseline.dart`: load/save JSON (unusedFiles, circularDependencies). CLI: `--baseline <file>`, `--update-baseline`. Exit 0 when no new violations vs baseline.

10. **HTML report** — `lib/src/cli/cross_file_html_reporter.dart` and `report` command. `--output-dir` (default reports). Writes index.html, unused-files.html, circular-deps.html.
